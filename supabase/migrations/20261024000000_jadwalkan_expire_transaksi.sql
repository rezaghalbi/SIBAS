-- =============================================================================
-- SIBAS — menjadwalkan expire_stale_transactions() lewat pg_cron
--
-- Tanpa penjadwalan, transaksi PENDING hanya berubah EXPIRED saat admin
-- membuka/menyetujui QR yang sudah lewat masa berlaku. Job ini memanggil
-- expire_stale_transactions() tiap 5 menit.
--
-- Migration idempoten dan aditif: tidak mengubah tabel/RPC yang sudah ada.
-- Bila pg_cron tidak tersedia (belum diaktifkan di project Supabase), migration
-- tetap sukses dan hanya memberi NOTICE; jalankan ulang setelah pg_cron aktif.
-- =============================================================================

do $$
begin
  create extension if not exists pg_cron;
exception
  when others then
    raise notice 'pg_cron tidak tersedia (%); penjadwalan dilewati.', sqlerrm;
end $$;

do $$
begin
  if to_regprocedure('cron.schedule(text, text, text)') is null then
    raise notice 'Fungsi cron.schedule tidak ditemukan; penjadwalan dilewati.';
  else
    -- Jadwal lama dengan nama sama dihapus dulu agar migration bisa diulang.
    begin
      perform cron.unschedule('expire-stale-transactions');
    exception
      when others then
        raise notice 'Tidak ada jadwal lama bernama expire-stale-transactions (%).', sqlerrm;
    end;

    perform cron.schedule(
      'expire-stale-transactions',
      '*/5 * * * *',
      'select public.expire_stale_transactions();'
    );
    raise notice 'Job expire-stale-transactions dijadwalkan tiap 5 menit.';
  end if;
end $$;
