# Audit Pra-Demo SIBAS

Status: **catatan analisis + implementasi pra-demo.**
Perubahan kode ada di working tree, **belum di-push** dan **belum diverifikasi
CI**. Bagian "Status implementasi" di §9 mencatat yang sudah/belum.
Tanggal: 2026-10-28
Sasaran: demo dengan beberapa ratus pengguna (mayoritas mahasiswa, 1–3 admin).
Ruang lingkup: keamanan, efisiensi web (Android/iOS/desktop), APK Android,
kesiapan operasi.
Di luar ruang lingkup: autentikasi (login/registrasi/reset/OTP), SMTP/email,
signing APK rilis. Keduanya tetap dicatat sebagai **dependensi** demo.

Sumber bukti:

- Repo: `origin/main` `6c4aebc` (merge PR #19), produksi Vercel dari run
  `39988833963`. Analyze & Test hijau `39988608790`.
- Produksi: `https://sibas.vercel.app`.
- Supabase: project `urhgqecrmyxzutvfowhm`, region `ap-southeast-1`,
  organisasi **Free** (`tier_free`), status `ACTIVE_HEALTHY`.
- Pengukuran jaringan: Chrome DevTools Protocol, cache kosong, emulasi
  1/2/5 Mbps.
- Audit database: `pg_policies`, `pg_proc.proacl`, `pg_indexes`, row counts.

---

## 1. Ringkasan eksekutif

**Kesimpulan: layak untuk demo terbatas setelah 6 gate wajib; belum layak
untuk rilis publik.**

Kekuatan yang sudah ada:

- Logika uang di server: `for update`, snapshot harga, saldo tidak bisa
  negatif, `available_balance` mengurangi penarikan PENDING.
- RLS aktif di semua tabel data; tulis transaksi hanya lewat RPC
  `security definer` dengan guard role.
- Audit setoran/penarikan tersimpan; akun dihapus lewat soft delete.
- QR setoran punya TTL; QR penarikan punya token acak; cron expire aktif
  tiap 5 menit.
- CI memblokir PR bila analyze/test gagal; deploy produksi hanya dari `main`.

Risiko utama demo (urut dampak):

1. **Cold load web 2,9 MB** → 5–14 detik di jaringan seluler; tanpa progres,
   terasa macet. Ini keluhan utama.
2. **Laporan admin bisa salah/terpotong**: filter tanggal/status hanya
   menyaring baris yang sudah dimuat (50–200), bukan di server.
3. **APK 71 MB** (universal 3 ABI) dan masih debug-signed (signing di luar
   lingkup, tetapi ukuran tetap menghambat distribusi).
4. **Supabase Free tidak punya backup** dan project pause setelah 7 hari
   idle. Tidak ada salinan data sebelum demo.
5. **Drift riwayat migration**: repo punya 14 file, riwayat remote hanya 12
   (maks `20261032000000`), padahal objek migration 33–35 sudah ada.
6. **Kebocoran kecil**: `available_balance(p_user)` bisa dipanggil semua user
   terautentikasi tanpa cek pemilik — **sudah ditutup 2026-10-28** (lihat §9).

Quick win sebelum demo (tanpa refactor besar):

- Pakai URL produksi yang sama untuk semua peserta, panaskan cache sehari
  sebelumnya; jangan bagikan URL preview.
- Tambah progres/timeout/retry di splash + `preconnect`/`preload`.
- Bundel font (hilangkan 6 request ke `fonts.gstatic.com`).
- Build APK `--split-per-abi` + hapus `--no-tree-shake-icons`.
- Ambil dump database + siapkan 2 admin + akun demo.
- Tutup `available_balance` dan revoke RPC yang masih PUBLIC.

### 1.1 Penjelasan sederhana (bahasa non-teknis)

- **Web terasa lambat** karena saat pertama dibuka, HP harus mengunduh
  ±2,9 MB "mesin aplikasi". Kedua kali biasanya cepat (0,6 detik) karena
  berkasnya sudah tersimpan di HP. Dari WhatsApp lebih parah karena browser
  mini di dalam WhatsApp sering tidak punya simpanan itu, dan kadang mematikan
  akselerasi grafis.
- **APK 71 MB** karena satu berkas berisi tiga versi untuk tiga jenis HP.
  Kalau dipecah, ukuran untuk HP modern turun menjadi sekitar 25 MB.
- **Laporan admin bisa salah** karena filter "hari ini"/"7 hari" hanya
  menyaring data yang sudah tampil di layar (50–200 baris), bukan seluruh
  data. Ekspor CSV ikut terpotong.
- **Keamanan**: ada satu pintu yang bisa membuka saldo mahasiswa lain bila
  seseorang tahu ID-nya; beberapa pintu lain masih terbuka untuk tamu meskipun
  petugas menolak; nama mahasiswa di CSV bisa berubah menjadi perintah Excel.
- **Data**: Supabase Free tidak punya salinan cadangan dan bisa "tidur" setelah
  7 hari tidak dipakai. Riwayat perubahan database di remote tidak sama dengan
  yang ada di repo.
- **Untuk 300 orang, kapasitas server cukup.** Yang perlu disiapkan bukan
  server lebih besar, melainkan satu link tetap, backup, 2 admin, akun demo,
  dan satu operator yang memantau.

---

## 2. Metode dan bukti

### 2.1 Pengukuran web (produksi, cache kosong)

| Kondisi | Frame Flutter pertama |
|---|---|
| 5 Mbps / 80 ms | 5,3 s |
| 2 Mbps / 150 ms | 13,9 s |
| 1 Mbps / 150 ms | 22,3 s |
| Cache hangat (kunjungan ulang) | 0,6–1,1 s |

Splash HTML muncul pada 0,8 s. Artinya pengguna melihat spinner statis
selama 4–21 detik.

### 2.2 Payload cold start (terkompresi brotli)

| Berkas | Ukuran | Asal |
|---|---|---|
| `main.dart.js` | 1,09 MB | Vercel |
| `canvaskit/chromium/canvaskit.wasm` | 1,52 MB | `www.gstatic.com` |
| `canvaskit.js` | 24 KB | `www.gstatic.com` |
| Plus Jakarta Sans 5 weight (TTF) + Roboto | ±217 KB | `fonts.gstatic.com` |
| logo + ikon | ±90 KB | Vercel |
| **Total** | **±2,9 MB** | 3 origin |

Catatan: `canvaskit/` ikut ter-build di Vercel, tetapi **tidak dipakai** —
loader memilih gstatic. Jangan self-host: Vercel mengirim varian chromium
2,08 MB, gstatic hanya 1,52 MB.

### 2.3 APK dari CI

Artefak `sibas-release-apk` run `39988833963`:

- Ukuran: **71 MB** (universal).
- `arm64-v8a`: `libflutter.so` 11,7 MB + `libapp.so` 7,9 MB +
  `libbarhopper_v3.so` 4,3 MB.
- `armeabi-v7a`: ±17,4 MB; `x86_64`: ±21 MB (tidak dipakai HP).
- `classes.dex` 2 MB; `--no-tree-shake-icons` membengkakkan font ikon.
- Tidak ada `ANDROID_KEYSTORE_*` di GitHub Secrets → debug-signed
  (di luar lingkup, tetapi menghalangi update di atas versi lama).
- Artefak CI hanya disimpan 7 hari.

### 2.4 Database saat ini

| Item | Nilai |
|---|---|
| Profiles | 6 (1 admin, 5 mahasiswa) |
| Transactions | 16 (0 PENDING) |
| Withdrawals | 5 (0 PENDING) |
| Trash types | 15 |
| Bank locations | 2 |
| `client_error_logs` | 0 |
| Ukuran `transactions` | 112 kB |
| Cron expire | `*/5 * * * *`, aktif |

---

## 3. Keamanan

### 3.1 RLS per tabel (hasil `pg_policies`)

| Tabel | SELECT | INSERT/UPDATE/DELETE | Catatan |
|---|---|---|---|
| `profiles` | self atau admin | update self | Trigger mengunci role/saldo/NIM/email; `full_name`/`phone` masih bebas |
| `trash_types` | semua authenticated | admin | — |
| `transactions` | self atau admin | tidak ada policy | Tulis hanya via RPC definer |
| `transaction_audits` | admin | tidak ada policy | Via RPC |
| `withdrawals` | self atau admin | tidak ada policy | Via RPC |
| `withdrawal_audits` | admin | tidak ada policy | Via RPC |
| `app_settings` | authenticated | tidak ada policy | Update via RPC admin |
| `bank_locations` | aktif, atau semua untuk admin | admin | — |
| `client_error_logs` | tidak ada policy | tidak ada policy | Hanya RPC definer |
| Storage `avatars` | folder sendiri | folder sendiri | Bucket privat |
| Storage `trash-type-images` | authenticated | admin | Bucket publik, 2 MB, MIME dibatasi |

Tidak ada tabel data yang terbuka tanpa RLS. Ini fondasi yang benar.

### 3.2 RPC dan hak eksekusi (hasil `pg_proc.proacl`)

`=X` berarti PUBLIC (termasuk anon).

| Fungsi | Hak eksekusi | Guard | Risiko | Tindakan |
|---|---|---|---|---|
| `create_deposit` | authenticated | `auth.uid()` | OK | — |
| `create_withdrawal` | authenticated | `auth.uid()` + lock | OK | — |
| `approve_transaction` | authenticated | `is_admin()` | OK | — |
| `approve_withdrawal` | authenticated | `is_admin()` + lock | OK | — |
| `tarik_by_qr` | authenticated | `is_admin()` | OK | — |
| `penarikan_by_qr` | authenticated | `is_admin()` | PUBLIC/anon sudah dicabut 2026-10-28; uji anon 401 | — |
| `hapus_jenis_sampah` | authenticated | `is_admin()` | PUBLIC/anon sudah dicabut 2026-10-28; uji anon 401 | — |
| `hapus_akun_sendiri` | authenticated | `auth.uid()` | PUBLIC/anon sudah dicabut 2026-10-28; uji anon 401 | — |
| `ubah_profil_sendiri` | authenticated | `auth.uid()` | PUBLIC/anon sudah dicabut 2026-10-28; uji anon 401 | — |
| `available_balance(p_user)` | authenticated | pemilik/admin (sejak 2026-10-28) | **Sudah ditutup**: uji self 200, user lain 400, admin 200 | — |
| `get_app_settings` | authenticated | — | Anon sudah dicabut 2026-10-28; hanya dipakai setelah login | — |
| `update_app_settings` | authenticated | `is_admin()` | PUBLIC/anon sudah dicabut 2026-10-28; uji anon 401 | — |
| `detail_transaksi` | authenticated | pemilik/admin | Bug NULL laten | Ganti `<>` dengan `is distinct from` + cek null |
| `detail_penarikan` | authenticated | pemilik/admin | Sama | Sama |
| `admin_metrics` | authenticated | `is_admin()` | OK | — |
| `simpan_lokasi` / `hapus_lokasi` | authenticated | `is_admin()` | OK | — |
| `get_locations` | authenticated | — | OK | — |
| `expire_stale_transactions` | service_role | — | OK | — |
| `is_admin` | authenticated | — | OK | — |
| `log_client_error` | **PUBLIC + anon** | rate limit 20/jam | Spam log anon | Batasi per IP atau turunkan prioritas |

**Temuan terpenting:** `available_balance` adalah `SECURITY DEFINER`, tidak
memeriksa pemilik, dan dapat dieksekusi `authenticated`. Secara teori seorang
mahasiswa dapat memanggil `available_balance('<uuid>')` untuk membaca saldo
mahasiswa lain. UUID tidak mudah ditebak, tetapi ini tetap kebocoran privasi
dan mudah ditutup.

### 3.3 Validasi dan abuse

| Temuan | Bukti | Dampak | Tindakan |
|---|---|---|---|
| CSV formula injection | `lib/features/verification/data/csv_export.dart` `_escape` hanya koma/kutip/newline | Nama `=...` dieksekusi Excel saat rekap dibuka | Prefix `'` untuk sel yang dimulai `= + - @` |
| Update profil langsung | `guard_profile_update` (migration 29) sudah mengunci `full_name`/NIM/`phone`; verifikasi definisi remote | Tidak ada lagi; PATCH langsung ditolak | — |
| Spam setoran | `create_deposit` hanya menolak duplikat jenis+berat dalam 2 menit | Satu akun bisa membanjiri antrean PENDING | Batasi jumlah PENDING per user (mis. 10) atau rate limit |
| Spam log anonim | `log_client_error` 20/jam **global untuk semua anon** | Log anon bisa dimatikan satu bot | Batasi per IP/anon id |
| Tanpa CAPTCHA/rate limit global | Registrasi/auth di luar lingkup | — | Catat sebagai risiko auth |
| Tanpa CSP | `web/vercel.json` hanya COOP/COEP | XSS/clickjacking belum dimitigasi berlapis | Tambah CSP, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, `frame-ancestors` |

### 3.4 Audit dan PII

- Audit ada untuk setoran (`transaction_audits`) dan penarikan
  (`withdrawal_audits`). Sejak 2026-10-28, perubahan admin pada identitas
  mahasiswa, lokasi, dan `app_settings` juga dicatat trigger
  `catat_audit_admin` ke tabel `admin_audits` (admin-only).
- `client_error_logs` menyimpan pesan + stack + platform + versi; retensi
  30 hari lewat cron `bersihkan-log-klien`. Tidak ada UI/admin pembaca;
  hanya lewat dashboard SQL.
- Tidak ada service_role di kode; hanya anon key via `--dart-define`. Sesuai
  aturan.

### 3.5 Temuan keamanan prioritas

**Sudah ditutup 2026-10-28:**

1. `available_balance` sekarang memeriksa pemilik; self 200, user lain 400,
   admin 200 (diuji lewat REST).
2. PUBLIC/anon dicabut dari `penarikan_by_qr`, `hapus_jenis_sampah`,
   `hapus_akun_sendiri`, `ubah_profil_sendiri`, `update_app_settings`,
   `get_app_settings`; uji anon menerima 401.
3. CSV formula injection ditutup di `csv_export.dart` + unit test.
4. `full_name`/NIM/`phone` sudah dikunci `guard_profile_update` (migration 29);
   PATCH langsung ditolak. Tidak perlu perubahan baru.
5. Header keamanan dasar ditambahkan di `web/vercel.json` (`nosniff`,
   `Referrer-Policy`, `Permissions-Policy`, `frame-ancestors`).
6. Retensi `client_error_logs` 30 hari lewat cron `bersihkan-log-klien`.

**Belum (P1, tidak menghambat demo):**

7. Batas jumlah PENDING per mahasiswa (anti-spam setoran).
8. Ganti perbandingan NULL di `detail_transaksi`/`detail_penarikan`
   (`is distinct from`) sebagai pengaman berlapis.
9. CSP penuh (`default-src`/`script-src`) setelah diuji di preview.

---

## 4. Efisiensi per platform

### 4.1 Web Android

**Status: paling terdampak.**

- Cold start 2,9 MB → 5–14 detik pada 5–2 Mbps.
- CanvasKit dari gstatic: DNS + TLS ke origin ketiga; jika gstatic diblokir
  jaringan kampus, aplikasi bisa berhenti di splash.
- In-app browser (WhatsApp/Instagram) bisa memakai WebView tanpa cache
  bersama atau tanpa WebGL; CanvasKit jatuh ke software rendering.
- Tidak ada progres/timeout/retry → terlihat macet.
- Nav bawah memakai `BackdropFilter`; pada CanvasKit Android blur dihitung
  ulang saat scroll → potensi jank setelah app terbuka.
- Cache hangat hanya 0,6–1,1 s, tetapi setiap URL preview baru = cold.

**Rekomendasi:**

1. Splash: preconnect gstatic, preload `main.dart.js`, progres bertahap,
   pesan gagal + tombol coba lagi setelah ±20 s.
2. Bundel Plus Jakarta Sans (3 weight) dan buang `google_fonts` runtime.
3. Pakai URL produksi tetap untuk demo; panaskan cache sehari sebelum.
4. Deteksi in-app browser/WebGL dan tampilkan anjuran "Buka di Chrome".
5. Pertimbangkan nav solid di mobile atau `RepaintBoundary` untuk blur.
6. Jangan self-host CanvasKit (lebih besar di Vercel).

### 4.2 Web iOS (Safari/PWA)

**Status: layak dengan catatan.**

- Varian CanvasKit penuh 2,94 MB (bukan chromium 1,52 MB) → cold start lebih
  berat dari Android.
- Safari membuang storage situs setelah 7 hari tanpa interaksi (ITP); demo
  hari yang sama aman, tetapi login ulang sebelum presentasi.
- Add to Home Screen tetap bisa tanpa service worker; ikon memakai
  `apple-touch-icon` 192 (Apple menyarankan 180).
- Splash gelap sekarang konsisten karena `themeMode` default `system`
  (rencana lama yang menghapus blok gelap perlu ditinjau ulang).
- Kamera QR: `getUserMedia` butuh HTTPS dan gesture; layar pindai sudah punya
  input token manual + galeri sebagai fallback — ini menyelamatkan demo.
- Unduh CSV: `revokeObjectURL` langsung setelah klik bisa membatalkan unduhan
  di Safari; sudah ada fallback salin ke clipboard, tetapi perlu diuji.
- Tidak ada service worker → tidak ada cache offline; kebijakan wajib online.

**Rekomendasi:**

1. Uji A2HS + mode standalone di iPhone nyata.
2. Ganti `apple-touch-icon` ke 180×180.
3. Uji kamera QR dan CSV; pastikan fallback manual benar-benar terlihat.
4. Jangan mengandalkan PWA install prompt di iOS (tidak ada); beri petunjuk
   Share → Add to Home Screen.

### 4.3 Web desktop

**Status: paling siap.**

- Cold 5,3 s di 5 Mbps; di LAN kampus biasanya 2–3 s; warm <1 s.
- Layar lebar sudah memakai `ContentWidth` 1120 px dan `AdaptiveShell`
  (rail ≥900 px).
- CanvasKit + blur masih memakai GPU; laptop tua bisa jank saat scroll nav.
- Tidak ada masalah instalasi; cukup browser modern (Chrome/Edge/Firefox/
  Safari). Uji zoom 100–150% dan lebar 1366/1920.

**Rekomendasi:** uji desktop 1366×768 dan 1920×1080; pastikan tidak ada
overflow di tabel/riwayat.

### 4.4 APK Android

**Status: berfungsi, tetapi berat untuk distribusi.**

- 71 MB universal; sebagian besar karena 3 ABI + `libbarhopper` (ML Kit) +
  `--no-tree-shake-icons`.
- `--split-per-abi` → arm64 sekitar 25 MB (estimasi dari isi APK).
- Debug-signed: update di atas versi lama bisa gagal; untuk demo, uninstall
  versi lama dulu.
- Tidak ada `isMinifyEnabled`/`isShrinkResources` di release block.
- Artefak CI hanya 7 hari; unduh dan simpan APK final sebelum demo.

**Rekomendasi:**

1. Build `--split-per-abi`, unggah 3 APK, distribusikan arm64.
2. Hapus `--no-tree-shake-icons` (tidak ada `IconData(...)` dinamis).
3. Pertimbangkan R8/resource shrinking setelah diuji.
4. Unduh APK final + simpan di dua tempat (lokal + Drive).
5. Signing tetap di luar lingkup, tetapi catat bahwa update antar-build
   debug tidak dijamin.

### 4.5 Isu web bersama

| Isu | Dampak | Rekomendasi |
|---|---|---|
| `main.dart.js` 1,09 MB | Beban utama | Deferred import layar admin (opsional, risiko sedang) |
| Font runtime 6 request | +0,5–1 s + font swap | Bundel 3 weight, preload |
| Tanpa preconnect/preload | +1 RTT | Preconnect gstatic, preload main.dart.js |
| Tanpa service worker | Tidak ada precache; Android install prompt tidak muncul | Terima untuk demo; catat trade-off |
| Preview URL unik | Semua uji PR cold | Pakai alias staging/produksi tetap |
| Splash statis | Terasa macet | Progres + timeout + retry |
| Blur nav | Jank di Android | Solid di mobile atau RepaintBoundary |
| Ikon 512 217 KB / 192 53 KB | Berat saat install | Optimasi PNG/WebP (rendah) |

---

## 5. Skalabilitas dan operasi untuk beberapa ratus pengguna

### 5.1 Batas platform

| Layanan | Paket | Batas relevan | Risiko demo |
|---|---|---|---|
| Supabase | **Free** | DB 500 MB, egress 5 GB, storage 1 GB, 50k MAU, **tanpa backup**, pause setelah 7 hari idle, 2 project aktif | **Tinggi**: tidak ada backup; pause bila lama tidak dipakai |
| Vercel | Hobby (asumsi) | 100 deployment/hari; bandwidth lihat dashboard | Rendah untuk 300 user |
| GitHub Actions | Free | Menit build | Rendah |

Perkiraan beban 300 user:

- Web: 300 × 3 kunjungan × 2,9 MB ≈ **2,6 GB** (Vercel), masih di bawah
  kuota Hobby umum (100 GB).
- Supabase: respons API kecil (KB), jauh di bawah 5 GB.
- DB: 300 profil + beberapa ribu transaksi < 50 MB, jauh di bawah 500 MB.
- Storage: avatar/trash image < 100 MB.
- MAU: 300 << 50k.
- Concurrency: puncak 30–60 request; PostgREST + Postgres Free cukup.

**Kesimpulan kapasitas: cukup untuk demo.** Yang berbahaya bukan kapasitas,
tetapi **tidak adanya backup** dan **pause 7 hari**.

### 5.2 Query dan index

Index yang ada sudah menutupi banyak jalur:

- `transactions(mahasiswa_id, created_at desc)`
- `transactions(status)`
- `transactions(location_id, created_at desc)`
- `withdrawals(mahasiswa_id, status)`
- `withdrawals(location_id, created_at desc)`
- `profiles(nim)` unik
- partial unique `withdrawals` PENDING per mahasiswa

Yang belum ada:

- index `transactions(created_at desc)` untuk daftar admin lintas user;
- index `withdrawals(created_at desc)`;
- index pencarian teks (`tx_code`, `profiles.full_name`, `profiles.nim`)
  — `ILIKE '%...%'` tidak memakai btree. Untuk beberapa ribu baris masih
  cepat; untuk puluhan ribu perlu `pg_trgm`.
- composite `(status, created_at desc)` bila filter status makin sering.

**Rekomendasi:** ukur `EXPLAIN ANALYZE` setelah data demo >1.000 baris;
tambah index hanya bila perlu. Jangan menambah index spekulatif sebelum
demo.

### 5.3 Concurrency dan konsistensi

- `approve_transaction` dan `approve_withdrawal` memakai `for update` →
  aman dari double-approve.
- `create_withdrawal` mengunci profil + partial unique index → satu PENDING
  per mahasiswa.
- `create_deposit` menolak duplikat jenis+berat dalam 2 menit; tetapi tidak
  membatasi jumlah PENDING total.
- Saldo adalah kolom yang di-update RPC; tidak ada ledger ganda. Risiko drift
  jika ada perubahan manual via SQL. **Jangan update saldo manual saat demo.**
- Tidak ada mekanisme reversal; kesalahan approve hanya bisa dibetulkan via
  SQL (lihat 6.2).

### 5.4 Drift migration (penting)

- Repo: **18 migration**, terakhir
  `20261039000000_audit_admin.sql`.
- Remote `supabase_migrations.schema_migrations`: **16 baris**, maks
  `20261039000000`; ada entri `20261023061110 lokasi_bank_sampah` yang tidak
  ada di repo.
- Migration 36–39 (keamanan, index, retensi, audit) diterapkan langsung ke
  remote 2026-10-28 dan tercatat.
- Objek migration 33–35 **ada** di remote (`app_settings`, `bank_locations`,
  kolom `location_id`, `admin_ubah_mahasiswa`), tetapi **tidak tercatat** di
  riwayat. Schema berjalan, riwayatnya tidak sinkron.

Konsekuensi:

- `supabase db push`/branch baru bisa gagal atau mencoba menerapkan ulang.
- Staging yang dibangun dari repo bisa berbeda dari produksi.
- Tidak ada cara deterministik membangun ulang production dari migration.

**Tindakan sebelum demo:** jangan menjalankan migration baru. Catat drift;
setelah demo, rekonsiliasi (tandai migration yang sudah diterapkan, atau
buat baseline baru). Untuk demo, remote yang ada dipakai apa adanya.

### 5.5 Backup dan pemulihan

- Supabase Free **tidak punya backup**. Tidak ada PITR.
- Sebelum demo: `pg_dump` database + unduh folder storage (avatar, foto
  jenis sampah) ke dua tempat.
- Simpan juga daftar akun admin dan konfigurasi `app_settings`.
- Setelah demo: ekspor data + log sebelum membersihkan akun uji.

### 5.6 Monitoring dan operasi

- `client_error_logs` ada, tetapi tidak ada dashboard/alert. Untuk demo,
  pantau lewat Supabase Logs/Table Editor secara berkala.
- Tidak ada APM/tracing. Gunakan log Vercel + Supabase saat demo.
- Siapkan satu operator yang memantau antrean PENDING dan log; satu admin
  cadangan.
- `session_idle_watcher` logout setelah 30 menit idle — bisa mengganggu
  demo yang lama. Pertimbangkan menaikkan batas atau login ulang sebelum
  sesi presentasi.

### 5.7 Dependensi autentikasi (di luar lingkup, tetapi blocking)

Walau auth tidak dianalisis, demo beberapa ratus orang bergantung pada:

- verifikasi email (Supabase default memakai email bawaan dengan rate limit
  rendah; tanpa SMTP, pendaftaran massal bisa gagal);
- reset password (belum ada SMTP yang layak);
- akun admin (saat ini hanya 1).

**Keputusan yang perlu diambil:** pra-buat akun demo dan/atau nonaktifkan
konfirmasi email untuk demo, atau sediakan SMTP. Jangan mengandalkan email
bawaan Supabase untuk ratusan pendaftaran.

---

## 6. Kesiapan alur demo

| Alur | Status | Catatan |
|---|---|---|
| Login/registrasi | Di luar lingkup | Bergantung pada keputusan email/akun demo |
| Dashboard mahasiswa | Siap | Data saldo/berat dari profil; refresh manual |
| Setor + QR | Siap | TTL 120 menit; cron expire 5 menit; lokasi wajib |
| Riwayat mahasiswa | Siap | Unit test status helper ada |
| Tarik dana | Siap | Satu PENDING per user; QR penarikan admin |
| Profil + avatar | Siap | Upload 1024 px, quality 85; storage privat |
| Pusat informasi | Siap | Kontak dari `app_settings` |
| Dashboard admin | Siap | Metrik total; belum ada rentang tanggal |
| Pengajuan admin | Siap | Refresh manual; belum auto-refresh |
| Pindai QR | Siap | Kamera + input token manual + galeri; kamera dijeda saat tab tidak aktif/app background/sheet terbuka (perubahan 2026-10-28, menunggu CI) |
| Riwayat + CSV | **Beresiko** | Filter tanggal/status lokal; ekspor terpotong 200 |
| Data mahasiswa | Siap (≤500) | Limit 500, pencarian lokal |
| Lokasi | Siap | Hapus = nonaktif bila ada riwayat |
| Pengaturan | Siap | TTL + kontak; tanpa audit |
| Hapus akun | Siap | Soft delete; email auth tetap terpakai |

### 6.1 Laporan admin (detail)

`admin_history_screen.dart`:

- `_status` dan `_days` hanya `setState` lokal; `adminFilterProvider.status`
  tidak diisi dari layar ini.
- `getAllTransactions()` tidak menerima `startDate`/`endDate`; filter tanggal
  mustahil dilakukan di server dari layar ini.
- `_match()` menyaring **baris yang sudah dimuat**; kalau data >50 baris,
  "Hari ini"/"7 hari" bisa salah.
- `adaLagi = list.length >= limit` menghitung hasil filter lokal; tombol
  "Muat lagi" bisa hilang padahal masih ada data server.
- Ekspor setoran memakai hasil `_match()` (maks 200 baris).
- Ekspor penarikan memakai `adminWithdrawalsProvider(null)`; **mengabaikan**
  `_status`/`_days`.

Dampak: rekap bisa tidak lengkap atau kosong; jika demo menampilkan ekspor,
ini akan terlihat.

### 6.2 Koreksi dan audit

- Tidak ada RPC koreksi/pembatalan setoran APPROVED.
- Salah berat/harga hanya bisa diperbaiki via SQL, yang akan mengubah saldo
  tanpa audit.
- Perubahan identitas mahasiswa, lokasi, dan pengaturan tidak masuk audit.
  Untuk demo, catat siapa yang mengubah dan kapan di luar aplikasi.

**Rekomendasi pasca-demo:** RPC `koreksi_transaksi` dengan alasan + audit +
penyesuaian saldo, dan tabel audit admin.

### 6.3 Information architecture (diterapkan 2026-10-28)

| Halaman | Peran | Isi |
|---|---|---|
| Dashboard admin | Ringkasan | Metrik, 5 transaksi terbaru, pintasan; tanpa pencarian/daftar penuh |
| Pengajuan admin | Antrean kerja | Hanya `PENDING`, tab Setoran/Penarikan, aksi setujui/tolak |
| Riwayat admin | Arsip | Semua status, tab Setoran/Penarikan, filter tanggal/status/pencarian, ekspor, read-only |
| Dashboard mahasiswa | Ringkasan | 4–5 setoran terakhir + tautan |
| Riwayat mahasiswa | Arsip | Tab Setoran/Penarikan, filter status |
| Tarik | Form | Form + tautan “Lihat riwayat penarikan” |
| Saldo | Ringkasan | Saldo + 4 penarikan terakhir + tautan |

Tautan memakai `?tab=penarikan`, dibaca oleh `HistoryScreen` dan
`AdminHistoryScreen`. Tidak ada perubahan schema untuk penyesuaian ini.

---

## 7. Checklist pra-demo

### D-7 (seminggu sebelum)

- [ ] Freeze fitur berisiko; hanya perbaikan P0.
- [ ] Putuskan URL demo: produksi `sibas.vercel.app` atau alias staging
      tetap (bukan URL preview).
- [ ] Ambil `pg_dump` + unduh storage ke dua tempat.
- [ ] Buat 2 akun admin; siapkan 5–10 akun mahasiswa demo.
- [ ] Putuskan kebijakan email/konfirmasi untuk pendaftaran demo.
- [ ] Seed jenis sampah, harga, dan 2 lokasi; verifikasi.
- [ ] Perbaiki `available_balance`, revoke PUBLIC, CSV injection.
- [ ] Ukur ulang cold load setelah perubahan web.
- [ ] Siapkan APK `--split-per-abi`; unduh artefak sebelum kedaluwarsa.
- [ ] Uji perangkat: Android low-end, iPhone Safari, desktop.

### D-1 (sehari sebelum)

- [ ] Deploy final ke produksi; jangan merge lagi setelahnya.
- [ ] Panaskan cache di semua perangkat demo (buka URL produksi 1–2 kali).
- [ ] Uji login, setor, scan QR, tarik, ekspor CSV, unggah foto.
- [ ] Uji mode standalone iOS (A2HS) dan kamera.
- [ ] Siapkan hotspot seluler sebagai cadangan Wi-Fi.
- [ ] Charge perangkat; siapkan kabel/power bank.
- [ ] Cetak/ringkas petunjuk: URL, akun, alur A2HS, kontak operator.
- [ ] Pastikan Supabase tidak dalam keadaan pause; buka dashboard.

### Hari-H

- [ ] Buka **URL produksi**, bukan preview.
- [ ] Gunakan Chrome Android / Safari iOS; hindari in-app browser untuk
      scan kamera.
- [ ] Admin membuka layar Pengajuan dan menekan refresh berkala.
- [ ] Operator memantau Supabase Logs + antrean PENDING.
- [ ] Fallback: APK arm64 + hotspot + input token manual.
- [ ] Jangan mengubah schema/saldo manual saat demo.

### Pasca-demo

- [ ] Ekspor transaksi/penarikan + `client_error_logs`.
- [ ] Nonaktifkan/bersihkan akun uji.
- [ ] Kembalikan `app_settings` bila diubah.
- [ ] Catat insiden dan waktu ke `LOG_PROGRESS.md`.
- [ ] Rekonsiliasi riwayat migration.

---

## 8. Rencana verifikasi

### 8.1 Web (cold/warm)

Ulangi pengukuran CDP pada 1/2/5 Mbps, cache kosong:

- target awal: tidak lebih buruk dari baseline (5,3 / 13,9 / 22,3 s);
- target setelah W1/W2: turun 1–2 s pada 2 Mbps + splash tidak lagi terasa
  macet;
- ukur warm <1,5 s.

### 8.2 Matriks perangkat

| Platform | Perangkat | Yang diuji |
|---|---|---|
| Android | Chrome, low-end | cold/warm, setor, scan, unggah, offline banner |
| Android | in-app WA | cold/warm, fallback "buka di Chrome" |
| iOS | Safari | A2HS, standalone, kamera, CSV, ITP |
| iOS | WhatsApp | buka link, fallback |
| Desktop | Chrome/Edge/Firefox/Safari | 1366/1920, zoom, tabel |
| APK | Android 10/13/14 | install, login, QR, upload, update |

### 8.3 Load test

- 300 user simulasi, 50 concurrent read (dashboard/riwayat).
- 10 concurrent approve/reject.
- Ukur p95 latency PostgREST, error rate, dan row lock contention.
- Pantau Supabase CPU/connections dan Vercel logs.

### 8.4 Probe keamanan

- Panggil RPC anon: `penarikan_by_qr`, `hapus_jenis_sampah`,
  `update_app_settings` → harus ditolak/guard.
- Panggil `available_balance` dengan UUID user lain sebagai mahasiswa →
  harus ditolak setelah fix.
- PATCH `profiles` langsung untuk `full_name`/`phone` → harus ditolak
  setelah fix.
- Ekspor CSV dengan nama `=2+2` → harus diawali `'`.
- Cek header CSP/`X-Content-Type-Options`/`Referrer-Policy`.

### 8.5 CI

- `Analyze & Test` pada PR.
- `Build Android APK & Deploy Web to Vercel` pada PR (preview) dan `main`
  (produksi).
- Catat run ID di `LOG_PROGRESS.md`.
- Jangan `workflow_dispatch` build APK di branch fitur (deploy produksi).

---

## 9. Status implementasi dan prioritas

### Sudah diterapkan di working tree (belum push/CI)

| Item | Bukti/file |
|---|---|
| Kamera scan mati saat tab tidak aktif/app background/sheet | `admin_scan_screen.dart` |
| `available_balance` hanya untuk pemilik/admin | migration `20261036000000`; uji REST self/other/admin |
| RPC PUBLIC/anon dicabut | migration `20261036000000`; uji anon 401 |
| CSV formula injection | `csv_export.dart` + test |
| Index daftar admin | migration `20261037000000` |
| Retensi log 30 hari | migration `20261038000000`; cron aktif |
| Audit perubahan admin | migration `20261039000000`; uji no-op settings menghasilkan baris audit |
| Splash progres/timeout/retry, preconnect, preload, ikon 180 | `web/index.html`, `web/icon-180.png` |
| Petunjuk Add to Home Screen iOS (dismissible) | `web/index.html` |
| Header keamanan web dasar | `web/vercel.json` |
| Font Plus Jakarta Sans dibundel | `assets/google_fonts/`, `pubspec.yaml`, `main.dart` |
| APK split + tree-shake icon | `.github/workflows/build-apk.yml` |
| Filter tanggal/status + ekspor penuh + CSV Safari | riwayat admin, repository, provider, `csv_download_web.dart` |
| Form jenis sampah jadi halaman penuh; menu campuran dihapus | `trash_type_form_screen.dart`, `trash_type_management_screen.dart`, router |
| Dashboard ringkasan, pengajuan hanya PENDING, riwayat bertab | `admin_dashboard_screen.dart`, `admin_submissions_screen.dart`, `admin_history_screen.dart`, `history_screen.dart` |

### P0 operasional yang masih manual (bukan kode)

1. `pg_dump` + unduh storage sebelum demo.
2. 2 admin + akun demo + keputusan email/konfirmasi.
3. URL produksi tetap + warm cache sehari sebelum.
4. Operator yang memantau log/antrean; admin cadangan.
5. Uji perangkat nyata (Android low-end, iPhone Safari, desktop).

### P1 — setelah demo / jika waktu

8. Audit admin (identitas, lokasi, settings).
9. RPC koreksi transaksi + audit.
10. `admin_metrics` dengan rentang tanggal.
11. Paginasi/pencarian mahasiswa di server (>500).
12. Index `created_at`/trgm setelah data bertambah.
13. CSP + security headers.
14. Retensi `client_error_logs`.
15. `pubspec.lock` + test RPC/RLS + widget test alur kritis.
16. Source map web + dashboard error log.

### P2 — jangka panjang

17. Service worker/precache (trade-off kebijakan online; install prompt
    Android).
18. Realtime/push notification.
19. Deferred loading layar admin untuk memotong `main.dart.js`.
20. Aksesibilitas (semantics, kontras, keyboard).
21. Rekap bulanan/PDF/kuitansi, multi-admin/role, restore akun.
22. Rekonsiliasi migration + baseline baru.

---

## 10. Keputusan yang perlu diambil

1. **URL demo**: produksi `sibas.vercel.app` (disarankan) atau alias
   staging tetap. Jangan URL preview.
2. **Akun demo**: pra-buat semua akun, atau izinkan registrasi massal?
   Jika registrasi, bagaimana konfirmasi email tanpa SMTP?
3. **Distribusi APK**: split arm64 via Drive/WhatsApp, atau hanya web?
   Siapa yang memegang APK final?
4. **Laporan**: apakah demo akan menampilkan ekspor CSV? Jika ya, perbaiki
   filter/ekspor dulu.
5. **Backup**: siapa yang menjalankan `pg_dump` dan di mana disimpan?
6. **Operator**: siapa yang memantau log/antrean saat demo? Siapa admin
   cadangan?
7. **Sesi idle 30 menit**: naikkan untuk demo atau biarkan?
8. **Free plan**: tetap Free (tanpa backup) atau upgrade Pro sementara untuk
   demo?

---

## 11. Lampiran

### 11.1 Perintah pengukuran (dipakai)

```bash
# ukuran payload terkompresi
for f in main.dart.js canvaskit/chromium/canvaskit.wasm flutter_bootstrap.js; do
  curl -s --compressed -o /dev/null -L -w "$f %{size_download} bytes %{time_total}s\n" \
    "https://sibas.vercel.app/$f"
done
```

Pengukuran frame Flutter memakai Chrome DevTools Protocol:
`Network.emulateNetworkConditions` (1/2/5 Mbps) + `Page.navigate` +
polling `document.querySelector('flt-glass-pane')`.

### 11.2 Query audit database

```sql
-- ACL fungsi
select p.proname, pg_get_function_identity_arguments(p.oid) as args,
       p.prosecdef as security_definer, p.proacl::text as acl
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' order by p.proname;

-- RLS
select tablename, policyname, cmd, roles::text, qual, with_check
from pg_policies where schemaname = 'public';

-- index
select tablename, indexname, indexdef
from pg_indexes where schemaname = 'public';
```

### 11.3 Referensi file

- `lib/features/history/presentation/screens/admin_history_screen.dart`
- `lib/features/verification/data/verification_repository.dart`
- `lib/features/withdrawal/data/withdrawal_repository.dart`
- `lib/features/verification/data/csv_export.dart`
- `lib/features/students/data/student_repository.dart`
- `lib/core/theme/theme_mode_controller.dart`
- `lib/main.dart`
- `web/index.html`, `web/vercel.json`, `web/manifest.json`
- `.github/workflows/analyze.yml`, `.github/workflows/build-apk.yml`
- `supabase/migrations/20261026000000_kunci_kolom_profil.sql`
- `supabase/migrations/20261035000000_penjaga_dan_laporan.sql`
- `supabase/migrations/20261034000000_lokasi_bank_sampah.sql`
- `docs/PLAN_PWA_IOS_SAFARI.md`

### 11.4 Catatan drift migration

Remote `schema_migrations` (12):

```
20261022000000 init
20261023000000 selaraskan_skema_dan_rpc
20261023061110 lokasi_bank_sampah   <-- tidak ada di repo
20261024000000 jadwalkan_expire_transaksi
20261025000000 metrik_admin
20261026000000 kunci_kolom_profil
20261027000000 log_klien
20261028000000 flag_hapus_akun
20261029000000 profil_lengkap
20261030000000 audit_penarikan
20261031000000 foto_jenis_sampah
20261032000000 qr_penarikan
```

Repo memiliki tambahan `20261033000000_pengaturan_aplikasi.sql`,
`20261034000000_lokasi_bank_sampah.sql`,
`20261035000000_penjaga_dan_laporan.sql`; objeknya ada di remote, tetapi
tidak tercatat di riwayat. Jangan `supabase db push` sebelum direkonsiliasi.

---

## 12. Status dokumen

- Dokumen ini adalah catatan; implementasi pra-demo ada di **working tree**
  (lihat §9) dan **belum di-push**.
- Migration 36–39 sudah diterapkan ke remote dan tercatat; 33–35 masih drift
  (lihat §5.4).
- CI `Analyze & Test`/build belum dijalankan untuk perubahan ini.
- Setelah push disetujui, jalankan PR → CI → uji perangkat, lalu perbarui
  dokumen ini dengan ID run dan hasil uji.
