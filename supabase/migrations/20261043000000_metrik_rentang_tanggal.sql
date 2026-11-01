-- =============================================================================
-- SIBAS — metrik admin dengan rentang tanggal
--
-- Fungsi baru (nama berbeda) agar klien lama yang masih memanggil
-- admin_metrics(p_location_id) tidak rusak selama masa transisi deploy.
-- p_end eksklusif.
-- =============================================================================

create or replace function public.admin_metrics_rentang(
  p_location_id uuid default null,
  p_start timestamptz default null,
  p_end timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_total numeric;
  v_pending int;
  v_approved int;
  v_rejected int;
  v_lokasi jsonb;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat melihat metrik.';
  end if;

  select coalesce(sum(weight), 0) into v_total
  from public.transactions
  where status = 'APPROVED'
    and (p_location_id is null or location_id = p_location_id)
    and (p_start is null or created_at >= p_start)
    and (p_end is null or created_at < p_end);

  select
    count(*) filter (where status = 'PENDING'),
    count(*) filter (where status = 'APPROVED'),
    count(*) filter (where status = 'REJECTED')
  into v_pending, v_approved, v_rejected
  from public.transactions
  where (p_location_id is null or location_id = p_location_id)
    and (p_start is null or created_at >= p_start)
    and (p_end is null or created_at < p_end);

  select coalesce(jsonb_agg(baris order by baris->>'name'), '[]'::jsonb)
  into v_lokasi
  from (
    select jsonb_build_object(
      'id', l.id,
      'name', l.name,
      'is_active', l.is_active,
      'total_weight_kg', coalesce(sum(t.weight) filter (where t.status = 'APPROVED'), 0),
      'pending_count', count(t.id) filter (where t.status = 'PENDING'),
      'approved_count', count(t.id) filter (where t.status = 'APPROVED'),
      'rejected_count', count(t.id) filter (where t.status = 'REJECTED')
    ) as baris
    from public.bank_locations l
    left join public.transactions t
      on t.location_id = l.id
     and (p_start is null or t.created_at >= p_start)
     and (p_end is null or t.created_at < p_end)
    group by l.id, l.name, l.is_active
  ) rekap;

  return jsonb_build_object(
    'total_weight_kg', v_total,
    'pending_count', v_pending,
    'approved_count', v_approved,
    'rejected_count', v_rejected,
    'location_id', p_location_id,
    'period_start', p_start,
    'period_end', p_end,
    'locations', v_lokasi
  );
end $function$;

revoke all on function public.admin_metrics_rentang(uuid, timestamptz, timestamptz)
  from public, anon;
grant execute on function public.admin_metrics_rentang(uuid, timestamptz, timestamptz)
  to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261043000000', 'metrik_rentang_tanggal')
on conflict (version) do nothing;
