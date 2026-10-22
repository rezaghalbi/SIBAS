# SIBAS System Rules & Architecture

## 1. Project Stack & Architecture
- **Framework:** Flutter (Mobile & Web PWA)
- **Architecture:** Clean Architecture + Feature-First (`data`, `domain`, `presentation`)
- **State Management:** Riverpod (`Notifier` & `AsyncNotifier`)
- **Routing:** GoRouter
- **Backend Services:** Supabase (Auth, Database RPC, Storage)

## 2. Design System: Apple Glassmorphism
- **Frosted Effect:** Gunakan `BackdropFilter` dengan `ImageFilter.blur(sigmaX: 12, sigmaY: 12)`.
- **Background Translucency:** Gunakan gradien tipis transparan (`Colors.white.withValues(alpha: 0.15)` ke `Colors.white.withValues(alpha: 0.05)` atau variasi dark mode setara).
- **Borders:** Terapkan garis tepi halus `Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.2)`.
- **Elevation:** Gunakan `BoxShadow` ber-radius blur besar (20–30) dengan opacity rendah (0.05–0.1).
- **Corners:** Radius sudut wajib tumpul dan konsisten (`BorderRadius.circular(16-24)`).
- **API:** `withOpacity` deprecated sejak Flutter 3.27 — wajib `withValues(alpha:)`.
- **Satu sumber efek:** semua efek kaca lewat `lib/core/widgets/glass_panel.dart` (`GlassPanel`). Dilarang membuat widget kaca duplikat.
- **Performa:** maksimal 1–2 `BackdropFilter` per layar (mahal di build web/CanvasKit).

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

