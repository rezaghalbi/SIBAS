# LOG PROGRESS

## 2026-10-23 — Pengaturan aplikasi, data mahasiswa, pencarian admin

**Database**
- `supabase/migrations/20261033000000_pengaturan_aplikasi.sql`: tabel
  `app_settings` satu baris (`qr_ttl_minutes` 5–1440, kontak email/lokasi/jam),
  RLS select untuk authenticated, RPC `get_app_settings` dan
  `update_app_settings` (khusus admin), serta `create_deposit` memakai TTL dari
  pengaturan (fallback 120 menit).
- Migration diterapkan ke project remote `urhgqecrmyxzutvfowhm`. Verifikasi SQL:
  `get_app_settings()` mengembalikan `qr_ttl_minutes=120`, kontak null.
- pg_cron dicek aktif: job `expire-stale-transactions` jadwal `*/5 * * * *`.

**Kode**
- Data layer baru: `AppSettingsModel`, repository/provider settings, validator
  TTL/email/teks; `StudentModel`, repository/provider mahasiswa, filter
  `saringMahasiswa`.
- Layar baru: `AdminStudentsScreen` (baca-saja, pencarian lokal, detail akun)
  dan `AdminSettingsScreen` (TTL QR + kontak). Route `/admin/students` dan
  `/admin/settings`; kartu menu di layar Kelola Jenis Sampah.
- Pusat Informasi membaca kontak dari `app_settings`; fallback "Belum diatur".
- Pencarian teks ditambahkan ke Pengajuan dan Riwayat admin, memakai
  `adminFilterProvider` yang sudah diterapkan `adminTransactionsProvider`.
- Versi `pubspec.yaml` naik ke `1.0.1+2`.

**Dokumentasi & uji**
- README: struktur folder, daftar migration 29–33, RPC baru, Data Mahasiswa &
  Pengaturan, reset sandi/QR penarikan, pemindai web, daftar test, keterbatasan.
- PLAN_RENCANA_LANJUTAN: pertanyaan kontak admin ditandai selesai lewat
  pengaturan.
- Unit test baru: `test/pengaturan_app_test.dart`,
  `test/student_filter_test.dart`.

**Verifikasi**
- RPC diuji lewat REST memakai akun admin/mahasiswa: `get_app_settings` 200,
  `update_app_settings` admin 200, mahasiswa ditolak ("Hanya admin..."), TTL 4
  ditolak. Query `profiles` admin mengembalikan 5 mahasiswa dengan kolom yang
  dipakai layar.
- `create_deposit` dengan TTL 30 menghasilkan `qr_expires_at` 30 menit; data uji
  `BS-2026-0018` sudah dihapus dan TTL dikembalikan ke 120.
- Belum ada run CI untuk batch ini; `flutter analyze`/`flutter test` tidak bisa
  dijalankan lokal. Menunggu izin push untuk CI Analyze & Test + preview.

**Blocked (langkah dashboard/user)**
- Site URL Supabase masih `http://localhost:3000`; Redirect URL
  `https://sibas.vercel.app/reset-password` belum di-allowlist; SMTP belum
  diatur.
- Keystore rilis/secret Android belum ada; APK masih debug-signed.
- iOS belum dibuat; uji kamera/PWA di perangkat nyata belum dilakukan.

## 2026-10-22 — Setup agent & CI (PR #1, branch `chore/agent-setup-ci`)

**Konfigurasi agent**
- `~/.config/opencode/oh-my-opencode-slim.json`: preset `9router` aktif, 6 agent pakai `9router/ds/deepseek-v4-flash`.
- Hapus `agent.explorer.model` (menunjuk `9router/9router-main-combo` yang tidak terdaftar).
- Hapus MCP `github` dari `opencode.json` project (header PAT placeholder, selalu gagal).

**Skills** (`.opencode/skills/`)
- `progress-logger` — diperbaiki: `skills.md` → `SKILL.md` (sebelumnya tidak ter-load).
- `ponytail` — lazy senior dev, MIT, dipasang ke oracle/designer/fixer.
- `sibas-glass-ui` — token glass + checklist + larangan `withOpacity`/widget duplikat.
- `systematic-debugging`, `test-driven-development`, `verification-before-completion` — versi yang disesuaikan: RED/GREEN dan verifikasi lewat CI, bukan lokal.

**CI**
- Baru: `.github/workflows/analyze.yml` (PR-only, `flutter analyze --no-fatal-infos` + test bila ada).
- `build-apk.yml`: Flutter dipin `3.47.7`; deploy produksi Vercel hanya dari `push` ke `main`, PR dapat preview.

**Aturan**
- `AGENTS.md`: `withOpacity` → `withValues`, satu `GlassPanel`, max 1–2 blur per layar, bagian 5 (verifikasi via CI), 6 (Supabase migration-only), 7 (keamanan).

**Kode**
- `verification_repository.dart`: perbaiki karakter rusak di awal file + lengkapi `getAllTransactions`, `getTransactionForVerification`, `approveTransaction`, `rejectTransaction`.
- `supabase/migrations/20261022000000_init.sql` ditambahkan ke repo.

**Hasil CI**
- `Analyze & Test` hijau (run 39726694566). Sisa 6 info lint di `main.dart` (`prefer_const_constructors`) dan 1 `anonKey` deprecated — tidak memblokir.
- Gate format dihapus: repo belum terformat dengan `dart format` 3.47 dan tidak ada formatter lokal.

**Ditunda**
- `GlassPanel` belum dibuat; `lib/` masih 0 `BackdropFilter`, jadi glassmorphism belum sesuai `AGENTS.md`.
