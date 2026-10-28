-- =============================================================================
-- SIBAS — index pencarian teks
--
-- Pencarian admin memakai ILIKE '%...%' pada kode transaksi, nama, dan NIM.
-- Index trigram menjaga query tetap cepat saat data bertambah.
-- =============================================================================

create extension if not exists pg_trgm;

create index if not exists transactions_tx_code_trgm_idx
  on public.transactions using gin (tx_code gin_trgm_ops);

create index if not exists profiles_full_name_trgm_idx
  on public.profiles using gin (full_name gin_trgm_ops);

create index if not exists profiles_nim_trgm_idx
  on public.profiles using gin (nim gin_trgm_ops);

insert into supabase_migrations.schema_migrations (version, name)
values ('20261041000000', 'index_pencarian_trgm')
on conflict (version) do nothing;
