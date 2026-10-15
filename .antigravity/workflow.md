# Operational Workflow Loop

SETIAP LINTASAN KERJA AGENT WAJIB MENGIKUTI SIKLUS INI:

Step 1: CONTEXT READING
- Baca `.antigravity/state.md` untuk identifikasi task aktif.
- Baca `.antigravity/contracts.md` untuk memastikan tidak ada duplikasi fungsi.

Step 2: IMPLEMENTATION
- Tulis kode secara modular sesuai batasan `instructions.md`.

Step 3: SELF-TESTING
- Jalankan pemeriksaan sesuai `.antigravity/testing_protocol.md`.

Step 4: REVIEW REQUEST (HANDOFF)
- Sajikan ringkasan perubahan dan hasil uji mandiri kepada user.
- TANYAKAN ACC USER. Dilarang memperbarui `state.md` ke status [x] sebelum user memberikan ACC.

Step 5: STATE UPDATE (POST-ACC)
- Setelah user menyetujui, perbarui `.antigravity/state.md` dan catat komponen baru ke `.antigravity/contracts.md`.