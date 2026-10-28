-- =============================================================================
-- SIBAS — pengerasan keamanan sebelum demo
--
-- 1. available_balance: pemanggil hanya boleh melihat saldo dirinya sendiri
--    (atau admin). Sebelumnya semua user terautentikasi bisa membaca saldo
--    user lain bila mengetahui UUID-nya.
-- 2. Cabut hak eksekusi PUBLIC/anon dari RPC yang tidak perlu dipanggil
--    sebelum login. Guard di dalam fungsi tetap dipertahankan sebagai lapis
--    kedua.
--
-- Tidak ada perubahan tabel/kolom. Semua fungsi dipertahankan signature-nya
-- agar klien yang sudah ada tetap kompatibel.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. available_balance dengan pemeriksaan pemilik
-- -----------------------------------------------------------------------------
create or replace function public.available_balance(p_user uuid)
returns numeric
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_saldo numeric;
begin
  -- Pakai IS DISTINCT FROM agar auth.uid() yang null tidak lolos.
  if p_user is null
     or (p_user is distinct from auth.uid() and not public.is_admin()) then
    raise exception 'Anda tidak berhak melihat saldo akun lain.';
  end if;

  select coalesce(p.balance, 0) - coalesce((
    select sum(w.amount)
    from public.withdrawals w
    where w.mahasiswa_id = p_user
      and w.status = 'PENDING'
  ), 0)
  into v_saldo
  from public.profiles p
  where p.id = p_user;

  return v_saldo;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 2. Cabut akses PUBLIC/anon dari RPC yang hanya untuk pengguna login
-- -----------------------------------------------------------------------------
revoke all on function public.get_app_settings() from public, anon;
grant execute on function public.get_app_settings() to authenticated;

revoke all on function public.update_app_settings(integer, text, text, text)
  from public, anon;
grant execute on function public.update_app_settings(integer, text, text, text)
  to authenticated;

revoke all on function public.penarikan_by_qr(uuid) from public, anon;
grant execute on function public.penarikan_by_qr(uuid) to authenticated;

revoke all on function public.hapus_jenis_sampah(uuid) from public, anon;
grant execute on function public.hapus_jenis_sampah(uuid) to authenticated;

revoke all on function public.hapus_akun_sendiri() from public, anon;
grant execute on function public.hapus_akun_sendiri() to authenticated;

revoke all on function public.ubah_profil_sendiri(text, text, text)
  from public, anon;
grant execute on function public.ubah_profil_sendiri(text, text, text)
  to authenticated;

-- log_client_error sengaja tetap bisa dipanggil anon: dipakai saat login
-- gagal/offline sebelum ada sesi. Rate limit di dalam fungsi tetap aktif.

insert into supabase_migrations.schema_migrations (version, name)
values ('20261036000000', 'keamanan_pra_demo')
on conflict (version) do nothing;
