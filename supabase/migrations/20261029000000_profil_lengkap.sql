-- =============================================================================
-- SIBAS — profil lengkap: nomor WhatsApp, foto profil, RPC edit profil
--
-- profiles nim/email/deleted_at dikunci trigger. Perubahan nama, NIM, dan
-- nomor WhatsApp lewat RPC ubah_profil_sendiri agar validasi dan pengecekan
-- unik terjadi di server. Foto profil diunggah ke bucket privat `avatars`
-- pada folder per pengguna, lalu klien hanya menyimpan path-nya.
-- =============================================================================

alter table public.profiles
  add column if not exists phone text;

alter table public.profiles
  add column if not exists avatar_path text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_phone_format'
  ) then
    alter table public.profiles
      add constraint profiles_phone_format
      check (phone is null or phone ~ '^[0-9+][0-9 -]{7,19}$');
  end if;
end $$;

-- Registrasi ikut menyimpan nomor WhatsApp dari metadata auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_phone text := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'phone', '')), '');
begin
  -- Nomor tidak valid diabaikan agar registrasi tidak gagal; dilengkapi di profil.
  if v_phone is not null and v_phone !~ '^[0-9+][0-9 -]{7,19}$' then
    v_phone := null;
  end if;

  insert into public.profiles (id, email, full_name, nim, role, phone)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'nim', ''),
    'mahasiswa',
    v_phone
  )
  on conflict (id) do nothing;
  return new;
end;
$function$;

-- Trigger: hanya RPC yang boleh mengubah identitas; kolom keuangan tetap
-- terkunci untuk semua jalur non-admin.
create or replace function public.guard_profile_update()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_ubah boolean := coalesce(current_setting('sibas.ubah_profil', true), '') = 'on';
  v_hapus boolean := coalesce(current_setting('sibas.hapus_akun', true), '') = 'on';
begin
  if auth.uid() is null then return new; end if;
  if public.is_admin() then return new; end if;

  if new.id <> old.id
     or new.role <> old.role
     or new.balance <> old.balance
     or new.total_weight <> old.total_weight
     or new.created_at is distinct from old.created_at
     or new.deleted_at is distinct from old.deleted_at then
    raise exception 'Hanya admin yang dapat mengubah peran, saldo, total berat, atau status akun.';
  end if;

  -- Dipanggil hapus_akun_sendiri(): anonimisasi identitas.
  if v_hapus then
    return new;
  end if;

  -- Dipanggil ubah_profil_sendiri(): nama, NIM, dan nomor WhatsApp.
  if v_ubah then
    return new;
  end if;

  if new.full_name is distinct from old.full_name
     or new.nim is distinct from old.nim
     or new.phone is distinct from old.phone then
    raise exception 'Gunakan formulir edit profil untuk mengubah nama, NIM, atau nomor WhatsApp.';
  end if;

  if new.email is distinct from old.email then
    raise exception 'Email hanya dapat diubah lewat menu Ubah Email.';
  end if;

  if new.avatar_path is distinct from old.avatar_path then
    if new.avatar_path is not null
       and new.avatar_path not like auth.uid()::text || '/%' then
      raise exception 'Lokasi foto profil tidak valid.';
    end if;
  end if;

  return new;
end;
$function$;

create or replace function public.ubah_profil_sendiri(
  p_full_name text,
  p_nim text,
  p_phone text
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid := auth.uid();
  v_nama text := btrim(coalesce(p_full_name, ''));
  v_nim text := nullif(btrim(coalesce(p_nim, '')), '');
  v_phone text := nullif(btrim(coalesce(p_phone, '')), '');
  v_row public.profiles;
begin
  if v_uid is null then
    raise exception 'Sesi tidak ditemukan. Masuk ulang.';
  end if;

  if char_length(v_nama) < 2 or char_length(v_nama) > 80 then
    raise exception 'Nama harus 2 sampai 80 karakter.';
  end if;

  if v_nim is not null and v_nim !~ '^[A-Za-z0-9]{3,20}$' then
    raise exception 'NIM hanya boleh huruf dan angka, 3 sampai 20 karakter.';
  end if;

  if v_phone is not null and v_phone !~ '^[0-9+][0-9 -]{7,19}$' then
    raise exception 'Nomor WhatsApp tidak valid. Contoh: 081234567890.';
  end if;

  begin
    perform set_config('sibas.ubah_profil', 'on', true);

    update public.profiles
       set full_name = v_nama,
           nim = v_nim,
           phone = v_phone
     where id = v_uid
     returning * into v_row;
  exception
    when unique_violation then
      raise exception 'NIM sudah dipakai akun lain.';
  end;

  if v_row.id is null then
    raise exception 'Profil tidak ditemukan.';
  end if;

  return to_jsonb(v_row);
end;
$function$;

revoke all on function public.ubah_profil_sendiri(text, text, text) from anon;
grant execute on function public.ubah_profil_sendiri(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: foto profil privat, satu folder per pengguna.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,
  2097152,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists avatars_select_own on storage.objects;
create policy avatars_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

insert into supabase_migrations.schema_migrations (version, name)
values ('20261029000000', 'profil_lengkap')
on conflict (version) do nothing;
