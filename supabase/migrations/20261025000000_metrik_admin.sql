-- =============================================================================
-- SIBAS — metrik dashboard admin dihitung di server
--
-- Sebelumnya klien menarik seluruh baris `transactions` lalu menghitung sendiri.
-- PostgREST membatasi jumlah baris (default 1000), sehingga metrik bisa meleset
-- tanpa pesan apa pun. RPC ini menghitung total berat dan jumlah per status
-- langsung di database, hanya untuk admin.
-- =============================================================================

create or replace function public.admin_metrics()
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
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat melihat metrik.';
  end if;

  select coalesce(sum(weight), 0) into v_total
  from public.transactions
  where status = 'APPROVED';

  select
    count(*) filter (where status = 'PENDING'),
    count(*) filter (where status = 'APPROVED'),
    count(*) filter (where status = 'REJECTED')
  into v_pending, v_approved, v_rejected
  from public.transactions;

  return jsonb_build_object(
    'total_weight_kg', v_total,
    'pending_count', v_pending,
    'approved_count', v_approved,
    'rejected_count', v_rejected
  );
end $function$;

grant execute on function public.admin_metrics() to authenticated;
