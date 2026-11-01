-- =============================================================================
-- SIBAS — audit perubahan admin
--
-- Perubahan identitas mahasiswa, lokasi, dan pengaturan aplikasi sebelumnya
-- tidak meninggalkan jejak. Trigger ini mencatat perubahan yang dilakukan
-- admin ke tabel `admin_audits`; klien tidak bisa menulis langsung.
-- =============================================================================

create table if not exists public.admin_audits (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  aksi text not null,
  target_table text not null,
  target_id text,
  detail jsonb,
  dibuat_pada timestamptz not null default now()
);

create index if not exists admin_audits_dibuat_idx
  on public.admin_audits (dibuat_pada desc);

alter table public.admin_audits enable row level security;

drop policy if exists admin_audits_select on public.admin_audits;
create policy admin_audits_select on public.admin_audits
  for select to authenticated
  using (public.is_admin());

revoke all on public.admin_audits from anon, authenticated;
grant select on public.admin_audits to authenticated;

create or replace function public.catat_audit_admin()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_actor uuid := auth.uid();
  v_target text;
  v_aksi text;
  v_detail jsonb;
begin
  -- Hanya perubahan yang dilakukan admin lewat sesi login.
  if v_actor is null or not public.is_admin() then
    return null;
  end if;

  if tg_table_name = 'profiles' then
    if tg_op = 'UPDATE'
       and (new.full_name is distinct from old.full_name
            or new.nim is distinct from old.nim
            or new.phone is distinct from old.phone
            or new.role is distinct from old.role
            or new.deleted_at is distinct from old.deleted_at) then
      v_target := new.id::text;
      v_aksi := 'ubah_profil';
      v_detail := jsonb_build_object(
        'full_name', new.full_name,
        'nim', new.nim,
        'phone', new.phone,
        'role', new.role,
        'deleted_at', new.deleted_at
      );
    end if;
  elsif tg_table_name = 'bank_locations' then
    if tg_op = 'DELETE' then
      v_target := old.id::text;
    else
      v_target := new.id::text;
    end if;
    if tg_op = 'INSERT' then
      v_aksi := 'tambah_lokasi';
      v_detail := jsonb_build_object('name', new.name, 'address', new.address);
    elsif tg_op = 'UPDATE' then
      v_aksi := 'ubah_lokasi';
      v_detail := jsonb_build_object(
        'name', new.name,
        'address', new.address,
        'is_active', new.is_active
      );
    else
      v_aksi := 'hapus_lokasi';
      v_detail := jsonb_build_object('name', old.name);
    end if;
  elsif tg_table_name = 'app_settings' then
    if tg_op = 'UPDATE' then
      v_target := new.id::text;
      v_aksi := 'ubah_pengaturan';
      v_detail := jsonb_build_object(
        'qr_ttl_minutes', new.qr_ttl_minutes,
        'contact_email', new.contact_email,
        'contact_location', new.contact_location,
        'contact_hours', new.contact_hours
      );
    end if;
  end if;

  if v_aksi is not null then
    insert into public.admin_audits (
      actor_id, aksi, target_table, target_id, detail
    ) values (
      v_actor, v_aksi, tg_table_name, v_target, v_detail
    );
  end if;

  return null;
end;
$function$;

drop trigger if exists audit_profiles on public.profiles;
create trigger audit_profiles
after update on public.profiles
for each row execute function public.catat_audit_admin();

drop trigger if exists audit_bank_locations on public.bank_locations;
create trigger audit_bank_locations
after insert or update or delete on public.bank_locations
for each row execute function public.catat_audit_admin();

drop trigger if exists audit_app_settings on public.app_settings;
create trigger audit_app_settings
after update on public.app_settings
for each row execute function public.catat_audit_admin();

insert into supabase_migrations.schema_migrations (version, name)
values ('20261039000000', 'audit_admin')
on conflict (version) do nothing;
