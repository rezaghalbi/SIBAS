# SIBAS System Rules & Architecture

## 1. Project Stack & Architecture
- **Framework:** Flutter (Mobile & Web PWA)
- **Architecture:** Clean Architecture + Feature-First (`data`, `domain`, `presentation`)
- **State Management:** Riverpod (`Notifier` & `AsyncNotifier`)
- **Routing:** GoRouter
- **Backend Services:** Supabase (Auth, Database RPC, Storage)

## 2. Design System: Apple Glassmorphism (Glass 2.0)
- **Spesifikasi mengikat:** `docs/DESIGN_SYSTEM_V2.md`. Prototipe visual: `reference/sibas-glass-2.html`. Token runtime: `lib/core/theme/app_palette.dart` (`AppPalette.of(context)`).
- **Peran ikut hierarki.** Lencana, chip status, dan tautan memakai ukuran/bobot, bukan warna acak. Angka uang, berat, dan rekap wajib `FontFeature.tabularFigures()`.
- **Frosted Effect:** Gunakan `BackdropFilter` dengan `ImageFilter.blur(sigmaX: 12, sigmaY: 12)`; tone `hero` boleh 8–12.
- **Background Translucency:** Gradien per tone — `subtle` putih `.20` → `.06` (dark `.13` → `.03`); `dense` (nav/sheet) putih `.88` → `.74` (dark `surfaceAlt`/`surface`); `hero` putih `.14` → `.08`.
- **Borders:** `Border.all(color: <glassBorder>, width: 1.2)`; tone `subtle` putih `.24`, `dense` dark `.16`. Plus inset highlight 1 px di sisi atas.
- **Elevation:** `BoxShadow` blur besar dengan opacity rendah (token `sm/md/lg` §5). Jangan gabungkan shadow tebal dengan border tebal.
- **Corners:** skala tetap — `12` ikon/badge, `16` field, `20` kartu, `24` nav, `28` hero/sheet, `pill` 999.
- **API:** `withOpacity` deprecated sejak Flutter 3.27 — wajib `withValues(alpha:)`.
- **Satu sumber efek:** semua efek kaca lewat `lib/core/widgets/glass_panel.dart` (`GlassPanel` dengan `tone: subtle | dense | hero`). Dilarang membuat widget kaca duplikat.
- **Performa:** maksimal 1–2 `BackdropFilter` per layar (mahal di build web/CanvasKit). Tidak ada kaca di dalam kaca.
- **Fallback:** `disableAnimations` / `prefers-reduced-motion` → solid tanpa blur; safe area wajib di hero, nav, dan sheet.
- **Mode gelap:** `AppTheme.darkTheme` sudah ada, tetapi `themeMode` masih `light` sampai layar selesai dimigrasi (tahap 5). Jangan mengandalkan `Theme.of(context).brightness` di layar yang belum dimigrasi.

## 3. Reference Files Context
- Buka dan pelajari file spesifikasi (DOCX) dan rancangan tata letak visual (HTML) di folder `reference/` sebelum merancang fungsi atau layar baru.

## 4. Execution Rules
- Jalankan tugas secara bertahap (maksimal 1–2 file per eksekusi).
- Sebelum menulis kode Flutter, selalu kembangkan rencana kerja di **Plan Mode** terlebih dahulu.
- Setelah pengodean selesai, pastikan `flutter analyze` hijau lewat CI (lihat bagian 5).

## 5. Verifikasi: Hanya Lewat CI (tidak ada SDK Flutter lokal)

Mesin pengembangan **tidak memiliki** Flutter/Dart SDK. `flutter analyze`, `flutter test`, `flutter build` tidak bisa dijalankan lokal. Jangan pernah mengklaim kode "sudah benar" tanpa bukti CI.

- Gate cepat: workflow `Analyze & Test` (`.github/workflows/analyze.yml`), jalan di setiap PR. Isinya `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`.
- Build penuh: `Build Android APK & Deploy Web to Vercel` (`.github/workflows/build-apk.yml`).
- Flutter dipin ke `3.47.7` di kedua workflow. Jangan hapus pin tanpa alasan.
- Perintah wajib sebelum melaporkan selesai:
  ```bash
  gh run list --branch <branch> --limit 5
  gh run watch <run-id> --exit-status
  gh run view <run-id> --log-failed
  ```
- PR hanya menghasilkan **preview** Vercel. Deploy produksi hanya dari `push` ke `main`.
- Skill terkait: `verification-before-completion`, `systematic-debugging`, `test-driven-development`.

## 6. Supabase
- Schema **hanya** diubah lewat file migration baru di `supabase/migrations/<timestamp>_<nama>.sql`. Satu migration per perubahan.
- Dilarang mengubah schema remote secara manual lewat MCP/SQL editor tanpa migration yang sesuai.
- RPC baru wajib punya migration + dipakai konsisten oleh repository di `features/*/data`.

## 7. Keamanan
- `service_role` key **tidak boleh** masuk repo maupun kode aplikasi. Hanya `anon` key.
- Konfigurasi sensitif lewat `--dart-define` (CI: GitHub Secrets) atau `.env` yang di-gitignore.
- Jangan pernah menulis token/secret ke file yang di-commit atau ke output percakapan.

## 8. Git: Push Butuh Persetujuan User
- `git add` / `git commit` boleh dilakukan lokal tanpa bertanya.
- `git push` **wajib menunggu persetujuan user** (`permission.shell: "git push*": "ask"` di `opencode.json`).
- `git push --force` / `-f` dilarang.
- Pola kerja: selesaikan satu unit kerja → commit lokal → tanya user → push → baca CI.
- Jangan menggabungkan push dengan pekerjaan yang belum selesai.

## 9. Aturan Pesan Commit

Tanpa prefix gaya Conventional Commits (`feat:`, `fix:`, `chore:`, `ft`, `wip`, dll). Tulis kalimat teknis biasa yang menjelaskan apa yang berubah.

Aturan:
- Baris pertama: perintah imperatif, ≤ 72 karakter, bahasa Indonesia teknis. Contoh: `Tambah validasi NIM unik pada registrasi mahasiswa`.
- Baris kedua kosong.
- Isi (opsional, maks 4 baris): **apa** yang berubah dan **mengapa**, sebut nama file/fungsi/RPC bila relevan. Tanpa basa-basi, tanpa pemasaran, tanpa kalimat gaya AI.
- Satu commit = satu perubahan logis. Jangan campur refactor dengan perubahan perilaku.
- Dilarang: `update`, `fix bug`, `perbaikan`, `misc`, `changes`, `refactor`, `WIP`.
- Sebutkan bukti verifikasi bila ada (nama workflow/run id), bukan klaim.

Contoh baik:
```
Batasi registrasi hanya untuk role mahasiswa

Role admin tidak lagi bisa dipilih dari klien. Role ditentukan di server
melalui seed, dan signUp menolak nilai role selain 'mahasiswa'.
```

Contoh buruk:
```
fix: perbaiki bug login
```
```
feat: improve UI glassmorphism ✨
```


