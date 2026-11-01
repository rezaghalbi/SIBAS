-- =============================================================================
-- SIBAS — rekonsiliasi riwayat migration
--
-- Objek migration 33–35 sudah diterapkan ke remote melalui SQL editor,
-- tetapi belum tercatat di supabase_migrations.schema_migrations. Catat
-- sebagai sudah diterapkan agar `supabase db push` tidak mencoba mengulang.
-- =============================================================================

insert into supabase_migrations.schema_migrations (version, name)
values
  ('20261033000000', 'pengaturan_aplikasi'),
  ('20261034000000', 'lokasi_bank_sampah'),
  ('20261035000000', 'penjaga_dan_laporan')
on conflict (version) do nothing;

insert into supabase_migrations.schema_migrations (version, name)
values ('20261045000000', 'rekonsiliasi_riwayat')
on conflict (version) do nothing;
