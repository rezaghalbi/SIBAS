-- =============================================================================
-- SIBAS — foto jenis sampah dan hapus aman
--
-- Admin dapat mengunggah satu foto per jenis sampah (bucket publik
-- `trash-type-images`, tulis hanya admin). Hapus memakai RPC: jenis yang sudah
-- dipakai transaksi dinonaktifkan (FK transactions memakai ON DELETE RESTRICT),
-- jenis yang belum dipakai dihapus permanen.
-- =============================================================================

alter table public.trash_types
  add column if not exists image_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'trash-type-images',
  'trash-type-images',
  true,
  2097152,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Baca lewat API storage (public URL tetap jalan tanpa policy); dibutuhkan
-- juga oleh operasi hapus/ubah objek.
drop policy if exists trash_type_images_select on storage.objects;
create policy trash_type_images_select on storage.objects
  for select to authenticated
  using (bucket_id = 'trash-type-images');

drop policy if exists trash_type_images_insert_admin on storage.objects;
create policy trash_type_images_insert_admin on storage.objects
  for insert to authenticated
  with check (bucket_id = 'trash-type-images' and public.is_admin());

drop policy if exists trash_type_images_update_admin on storage.objects;
create policy trash_type_images_update_admin on storage.objects
  for update to authenticated
  using (bucket_id = 'trash-type-images' and public.is_admin())
  with check (bucket_id = 'trash-type-images' and public.is_admin());

drop policy if exists trash_type_images_delete_admin on storage.objects;
create policy trash_type_images_delete_admin on storage.objects
  for delete to authenticated
  using (bucket_id = 'trash-type-images' and public.is_admin());

create or replace function public.hapus_jenis_sampah(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_exists boolean;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat menghapus jenis sampah.';
  end if;

  select true into v_exists from public.trash_types where id = p_id;
  if v_exists is null then
    raise exception 'Jenis sampah tidak ditemukan.';
  end if;

  if exists (select 1 from public.transactions where trash_type_id = p_id) then
    update public.trash_types set is_active = false where id = p_id;
    return jsonb_build_object('mode', 'nonaktif');
  end if;

  delete from public.trash_types where id = p_id;
  return jsonb_build_object('mode', 'hapus');
end;
$function$;

revoke all on function public.hapus_jenis_sampah(uuid) from anon;
grant execute on function public.hapus_jenis_sampah(uuid) to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261031000000', 'foto_jenis_sampah')
on conflict (version) do nothing;
