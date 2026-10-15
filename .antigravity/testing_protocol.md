# Self-Testing Checklist (Lakukan Sebelum Minta ACC)

1. Static Analysis: Pastikan tidak ada error atau unused imports (`flutter analyze`).
2. Business Logic Verification:
   - [ ] Apakah berat diinput manual dalam satuan kg?
   - [ ] Apakah QR hanya memuat `transaction_id` UUID?
   - [ ] Apakah validasi 2 jam dan perubahan saldo ditangani penuh oleh server/RPC?
   - [ ] Apakah palet warna dan logo sudah sesuai `design_system.md`?
3. Output Format Laporan ke User:
   - Rincian Berkas Dibuat/Diubah.
   - Hasil Self-Testing Protocol.
   - Draf Kode / Diff.
   - Pertanyaan Konfirmasi: *"Apakah task ini disetujui (ACC) untuk dilanjutkan ke task berikutnya?"*