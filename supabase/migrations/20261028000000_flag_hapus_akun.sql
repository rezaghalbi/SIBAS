-- =============================================================================
-- SIBAS — hapus akun lewat penandaan (soft delete)
--
-- Menghapus baris auth.users akan menghapus riwayat setoran/penarikan karena
-- FK memakai ON DELETE CASCADE. Karena itu akun hanya ditandai:
--   * profiles.deleted_at diisi, nama/NIM/email dianonimkan
--   * sesi dicabut dan login diblokir (auth.users.banned_until = infinity)
-- Riwayat transaksi tetap utuh untuk audit.
--
-- Syarat: saldo 0 dan tidak ada pengajuan PENDING.
-- =============================================================================

alter table public.profiles
  add column if not exists deleted_at timestamptz;

-- Izinkan trigger guard_profile_update melewati pemeriksaan kolom sensitif
-- hanya ketika dipanggil dari hapus_akun_sendiri().
create or replace function public.guard_profile_update()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  -- Penghapusan akun (dipanggil hapus_akun_sendiri) boleh mengubah kolom
  -- identitas sekali; klien tidak bisa memalsukan karena set_config hanya
  -- berlaku di transaksi function tersebut.
  if coalesce(current_setting('sibas.hapus_akun', true), '') = 'on' then
    return new;
  end if;

  if new.id <> old.id
     or new.role <> old.role
     or new.balance <> old.balance
     or new.total_weight <> old.total_weight
     or new.nim is distinct from old.nim
     or new.email is distinct from old.email
     or new.created_at is distinct from old.created_at
     or new.deleted_at is distinct from old.deleted_at then
    raise exception 'Hanya admin yang dapat mengubah peran, saldo, NIM, atau total berat.';
  end if;

  return new;
end $function$;

create or replace function public.hapus_akun_sendiri()
returns void
language plpgsql
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_uid uuid := auth.uid();
  v_saldo numeric;
  v_pending int;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan. Masuk ulang.';
  end if;

  if exists (
    select 1 from public.profiles
    where id = v_uid and deleted_at is not null
  ) then
    raise exception 'Akun ini sudah ditandai terhapus.';
  end if;

  select coalesce(public.available_balance(v_uid), 0) into v_saldo;
  if v_saldo > 0 then
    raise exception 'Saldo masih ada. Tarik saldo sampai nol sebelum menghapus akun.';
  end if;

  select
    (select count(*) from public.transactions
      where mahasiswa_id = v_uid and status = 'PENDING')
    + (select count(*) from public.withdrawals
      where mahasiswa_id = v_uid and status = 'PENDING')
  into v_pending;

  if v_pending > 0 then
    raise exception 'Masih ada pengajuan yang belum selesai. Tunggu validasi admin.';
  end if;

  -- Tandai transaksi ini agar trigger profil melewati pemeriksaan kolom.
  perform set_config('sibas.hapus_akun', 'on', true);

  update public.profiles
     set deleted_at = now(),
         full_name = 'Akun dihapus',
         nim = null,
         email = null
   where id = v_uid;

  -- Cabut sesi aktif dan blokir login berikutnya.
  delete from auth.sessions where user_id = v_uid;
  update auth.users set banned_until = 'infinity' where id = v_uid;
end $function$;

revoke all on function public.hapus_akun_sendiri() from anon;
grant execute on function public.hapus_akun_sendiri() to authenticated;
