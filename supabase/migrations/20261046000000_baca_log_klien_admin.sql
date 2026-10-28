-- =============================================================================
-- SIBAS — admin dapat membaca client_error_logs
--
-- Sebelumnya tabel hanya bisa ditulis lewat RPC dan tidak punya policy baca.
-- Tambahkan policy select khusus admin agar dashboard log error bisa memakai
-- PostgREST tanpa memberi akses ke pengguna biasa.
-- =============================================================================

alter table public.client_error_logs enable row level security;

drop policy if exists client_error_logs_admin_select on public.client_error_logs;
create policy client_error_logs_admin_select on public.client_error_logs
  for select to authenticated
  using (public.is_admin());

grant select on public.client_error_logs to authenticated;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261046000000', 'baca_log_klien_admin')
on conflict (version) do nothing;
