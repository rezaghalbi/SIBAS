# Antigravity Strict Directives

## 1. Rules Anti-Halusinasi & Anti-Redundansi
- BACA `contracts.md` SEBELUM menulis kode baru. Jangan membuat fungsi/widget yang sudah ada.
- Gunakan arsitektur Feature-First pada Flutter.
- Gunakan `flutter_riverpod` untuk State Management, `go_router` untuk Routing, dan `supabase_flutter` untuk Client Database.

## 2. Alur Eksekusi Wajib
- Langkah 1: Baca `.antigravity/state.md` untuk identifikasi task aktif.
- Langkah 2: Tulis kode sesuai spesifikasi di `prd.md` dan `design_system.md`.
- Langkah 3: Jalankan verifikasi mandiri sesuai `testing_protocol.md`.
- Langkah 4: Tampilkan ringkasan perubahan dan ajukan permintaan ACC ke User.
- Langkah 5: PERBARUI `state.md` dan `contracts.md` HANYA SETELAH User memberikan ACC.