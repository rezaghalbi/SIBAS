-- =============================================================================
-- SIBAS — perbaikan otorisasi detail
--
-- `detail_transaksi`/`detail_penarikan` sebelumnya memakai `<>` terhadap
-- auth.uid(). Bila uid null, hasilnya NULL dan pemeriksaan tidak melempar.
-- Sekarang uid wajib ada dan perbandingan memakai IS DISTINCT FROM.
-- =============================================================================

create or replace function public.detail_transaksi(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_tx public.transactions;
begin
  if v_uid is null then
    raise exception 'Sesi tidak valid. Silakan login ulang.';
  end if;

  select * into v_tx from public.transactions where id = p_id;
  if not found then raise exception 'Transaksi tidak ditemukan.'; end if;
  if not public.is_admin()
     and v_tx.mahasiswa_id is distinct from v_uid then
    raise exception 'Anda tidak berhak melihat transaksi ini.';
  end if;

  return to_jsonb(v_tx)
    || jsonb_build_object('trash_name', (
         select name from public.trash_types where id = v_tx.trash_type_id))
    || jsonb_build_object('location', case
         when v_tx.location_id is null then null
         else (select jsonb_build_object(
                        'id', l.id, 'name', l.name, 'address', l.address,
                        'latitude', l.latitude, 'longitude', l.longitude)
               from public.bank_locations l where l.id = v_tx.location_id)
       end)
    || jsonb_build_object('mahasiswa', (
         select jsonb_build_object('full_name', full_name, 'nim', nim)
         from public.profiles where id = v_tx.mahasiswa_id))
    || jsonb_build_object('verifikator', (
         select jsonb_build_object('full_name', full_name)
         from public.profiles where id = v_tx.verified_by))
    || jsonb_build_object('audits', coalesce((
         select jsonb_agg(jsonb_build_object(
                  'from_status', a.from_status,
                  'to_status', a.to_status,
                  'note', a.note,
                  'created_at', a.created_at,
                  'actor_name', p.full_name) order by a.created_at)
         from public.transaction_audits a
         left join public.profiles p on p.id = a.actor_id
         where a.transaction_id = v_tx.id), '[]'::jsonb));
end;
$function$;

create or replace function public.detail_penarikan(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_row public.withdrawals;
begin
  if v_uid is null then
    raise exception 'Sesi tidak valid. Silakan login ulang.';
  end if;

  select * into v_row from public.withdrawals where id = p_id;
  if not found then raise exception 'Penarikan tidak ditemukan.'; end if;
  if not public.is_admin()
     and v_row.mahasiswa_id is distinct from v_uid then
    raise exception 'Anda tidak berhak melihat penarikan ini.';
  end if;

  return to_jsonb(v_row)
    || jsonb_build_object('location', case
         when v_row.location_id is null then null
         else (select jsonb_build_object(
                        'id', l.id, 'name', l.name, 'address', l.address,
                        'latitude', l.latitude, 'longitude', l.longitude)
               from public.bank_locations l where l.id = v_row.location_id)
       end)
    || jsonb_build_object('mahasiswa', (
         select jsonb_build_object('full_name', full_name, 'nim', nim)
         from public.profiles where id = v_row.mahasiswa_id))
    || jsonb_build_object('verifikator', (
         select jsonb_build_object('full_name', full_name)
         from public.profiles where id = v_row.verified_by))
    || jsonb_build_object('audits', coalesce((
         select jsonb_agg(jsonb_build_object(
                  'from_status', a.from_status,
                  'to_status', a.to_status,
                  'note', a.note,
                  'created_at', a.created_at,
                  'actor_name', p.full_name) order by a.created_at)
         from public.withdrawal_audits a
         left join public.profiles p on p.id = a.actor_id
         where a.withdrawal_id = v_row.id), '[]'::jsonb));
end;
$function$;

revoke all on function public.detail_transaksi(uuid) from public, anon;
revoke all on function public.detail_penarikan(uuid) from public, anon;
grant execute on function public.detail_transaksi(uuid) to authenticated;
grant execute on function public.detail_penarikan(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261042000000', 'perbaikan_otorisasi_detail')
on conflict (version) do nothing;
