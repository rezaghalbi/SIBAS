-- =============================================================================
-- SIBAS — kunci kolom sensitif pada tabel profiles
--
-- Policy `profiles_update_self` mengizinkan pengguna meng-update barisnya
-- sendiri, tetapi tanpa batas kolom. Artinya mahasiswa bisa mengirim
-- `role = 'admin'` atau `balance = 999999` langsung ke PostgREST.
-- Trigger ini menolak perubahan kolom sensitif dari klien biasa; admin dan
-- konteks server (auth.uid() null, mis. migrasi/SQL editor) tetap boleh.
-- =============================================================================

create or replace function public.guard_profile_update()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  -- Konteks server (SQL editor, job, migrasi): tanpa JWT pengguna.
  if auth.uid() is null then
    return new;
  end if;

  if public.is_admin() then
    return new;
  end if;

  if new.id <> old.id
     or new.role <> old.role
     or new.balance <> old.balance
     or new.total_weight <> old.total_weight
     or new.nim is distinct from old.nim
     or new.email is distinct from old.email
     or new.created_at is distinct from old.created_at then
    raise exception 'Hanya admin yang dapat mengubah peran, saldo, NIM, atau total berat.';
  end if;

  return new;
end $function$;

drop trigger if exists profiles_guard_update on public.profiles;

create trigger profiles_guard_update
before update on public.profiles
for each row
execute function public.guard_profile_update();
