-- =============================================================================
-- SIBAS — index untuk daftar/riwayat admin
--
-- Daftar admin mengurutkan seluruh transaksi/penarikan berdasarkan created_at
-- dan sering memfilter status. Index lama hanya menutup jalur per mahasiswa
-- atau per lokasi. Tambahan ini menjaga query tetap cepat saat data demo
-- bertambah (ratusan mahasiswa, ribuan transaksi).
-- =============================================================================

create index if not exists transactions_created_idx
  on public.transactions (created_at desc);

create index if not exists withdrawals_created_idx
  on public.withdrawals (created_at desc);

create index if not exists transactions_status_created_idx
  on public.transactions (status, created_at desc);

create index if not exists withdrawals_status_created_idx
  on public.withdrawals (status, created_at desc);

insert into supabase_migrations.schema_migrations (version, name)
values ('20261037000000', 'index_daftar_admin')
on conflict (version) do nothing;
