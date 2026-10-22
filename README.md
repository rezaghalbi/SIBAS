# SIBAS

Sistem Informasi Bank Sampah Poltekkes Kemenkes Yogyakarta. Aplikasi Flutter
(mobile + web PWA) dengan backend Supabase.

## Stack

- Flutter/Dart (dipin ke **3.47.7** di CI)
- Riverpod (`Notifier`/`AsyncNotifier`) untuk state management
- GoRouter untuk navigasi
- Supabase: Auth dan Postgres (RPC)
- Desain: Apple Glassmorphism (aturan di `AGENTS.md`)

## Struktur Folder

```
lib/
  main.dart                  # entrypoint, baca --dart-define, init Supabase
  core/
    constants/               # warna & tema
    network/                 # inisialisasi Supabase
    router/                  # GoRouter
    utils/                   # helper status
    widgets/                 # widget bersama (glass panel, kartu, badge)
  features/
    auth/                    # login, register, sesi
    dashboard/
    deposit/                 # pengajuan setoran + tampilan QR
    verification/            # scan & verifikasi admin
    history/
    withdrawal/              # penarikan saldo
    trash_type/              # master jenis sampah
    students/                # daftar mahasiswa (admin, baca saja)
    info/                    # pusat informasi + pengaturan aplikasi
supabase/migrations/         # schema, RLS, RPC (satu migration per perubahan)
```

Pola per fitur: `data/` (repository Supabase), `domain/models/`, `presentation/`
(providers + screens).

## Setup Environment

Mesin pengembangan **tidak** punya Flutter/Dart SDK lokal. Kredensial dibaca
saat compile lewat `--dart-define` (lihat `lib/main.dart`). Daftar nama variabel
ada di `.env.example`; nilainya tidak boleh di-commit.

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Tanpa kedua variabel tersebut aplikasi menampilkan layar "Konfigurasi Supabase
belum diisi.". Hanya `anon` key yang boleh dipakai klien; `service_role` tidak
boleh masuk repo maupun kode aplikasi.

Migration dijalankan lewat Supabase CLI:

```bash
supabase db push
```

Isi migration:
- `20261022000000_init.sql` — skema awal, RLS, RPC.
- `20261023000000_selaraskan_skema_dan_rpc.sql` — menyelaraskan database lama
  dengan rancangan (kolom tx_code/qr_token/saldo, audit, penarikan, RPC baru).
- `20261024000000_jadwalkan_expire_transaksi.sql` — job pg_cron
  `expire-stale-transactions` tiap 5 menit. Bila pg_cron belum aktif, migration
  tetap sukses dan hanya memberi NOTICE.
- `20261025000000_metrik_admin.sql` — RPC `admin_metrics()`; metrik dashboard
  admin dihitung di server, bukan dari seluruh baris `transactions` di klien.
- `20261026000000_kunci_kolom_profil.sql` — trigger `profiles_guard_update`
  (fungsi `guard_profile_update`) menolak perubahan kolom sensitif `profiles`
  dari klien biasa.
- `20261027000000_log_klien.sql` — tabel `client_error_logs` dan RPC
  `log_client_error`; RLS aktif tanpa policy baca/tulis langsung, dibatasi 20
  catatan per pengguna/anon per jam.
- `20261028000000_flag_hapus_akun.sql` — kolom `profiles.deleted_at`, RPC
  `hapus_akun_sendiri()`, dan pengecualian trigger untuk anonimisasi akun.
- `20261029000000_profil_lengkap.sql` — kolom `phone`/`avatar_path`, bucket
  `avatars`, RPC `ubah_profil_sendiri`, validasi profil.
- `20261030000000_audit_penarikan.sql` — audit status penarikan dan detail
  penarikan untuk admin.
- `20261031000000_foto_jenis_sampah.sql` — kolom foto jenis sampah di bucket
  `trash-types`.
- `20261032000000_qr_penarikan.sql` — `qr_token` penarikan dan RPC
  `get_withdrawal_by_qr`.
- `20261033000000_pengaturan_aplikasi.sql` — tabel `app_settings` (satu baris),
  RPC `get_app_settings`/`update_app_settings`, dan `create_deposit` memakai
  `qr_ttl_minutes` dari pengaturan (default 120 menit).

## Perintah

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test

flutter build web --release \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

flutter build apk --release --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

`test/` berisi uji unit (`api_guard_test.dart`, `auth_error_message_test.dart`,
`status_helper_test.dart`, `withdrawal_model_test.dart`); belum ada widget atau
integration test.

## Android

Folder `android/` sudah ada di repo, jadi langkah CI "Generate Android
Scaffolding if Missing" tidak lagi membuat ulang scaffold. `applicationId`
adalah `com.sibas.poltekkes.sibas`. `versionCode`/`versionName` membaca
`version:` di `pubspec.yaml` (saat ini `1.0.1+2`); naikkan nilai itu setiap
rilis.

`android/app/build.gradle.kts` membaca `android/key.properties` (tidak
di-commit, ada di `android/.gitignore`). Bila file itu tidak ada, APK release
ditandatangani debug key sehingga tidak bisa di-update di atas versi lama.
Untuk signing rilis:

```bash
keytool -genkeypair -v -keystore sibas-release.jks \
  -alias sibas -keyalg RSA -keysize 2048 -validity 10000
```

Letakkan `sibas-release.jks` di `android/app/keystore.jks`, lalu isi
`android/key.properties`:

```properties
storeFile=keystore.jks
storePassword=<store-password>
keyAlias=sibas
keyPassword=<key-password>
```

Konversi keystore ke base64 (macOS `base64 -i android/app/keystore.jks | pbcopy`;
Linux `base64 -w 0 android/app/keystore.jks`), lalu isi empat secret repo
GitHub Actions:

| Secret | Isi |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Hasil base64 `keystore.jks` |
| `ANDROID_STORE_PASSWORD` | Sandi keystore |
| `ANDROID_KEY_ALIAS` | Alias key (contoh: `sibas`) |
| `ANDROID_KEY_PASSWORD` | Sandi key |

Workflow mendekode base64 ke `android/app/keystore.jks` dan membuat
`android/key.properties` dari secret tersebut. Bila
`ANDROID_KEYSTORE_BASE64` kosong, workflow hanya memberi warning dan APK
memakai debug key.

## Akun Uji

| Peran | Email | Sandi |
| --- | --- | --- |
| Admin | `adminsibas@yopmail.com` | `password1!` |
| Mahasiswa | `mahasiswasibas@yopmail.com` | `password1!` |

Sandi ini **wajib diganti** sebelum dipakai di luar pengujian. Role tidak bisa
dipilih dari klien: registrasi selalu membuat `mahasiswa`, admin hanya lewat
seed/Dashboard Supabase.

Catatan pembuatan akun manual lewat SQL: isi kolom token GoTrue dengan string
kosong (`''`) — `confirmation_token`, `recovery_token`, `email_change`,
`email_change_token_new`, `phone_change`, `phone_change_token`. Bila kolom itu
`NULL`, login membalas 500 `Database error querying schema`.

## Sesi & Keamanan

- Sesi disimpan oleh Supabase di penyimpanan browser. `CurrentUserNotifier`
  mendengarkan `onAuthStateChange`; event `signedOut` (logout di tab/perangkat
  lain atau token kedaluwarsa) langsung mengosongkan pengguna aktif, lalu
  `refreshListenable` GoRouter mengarahkan ke `/login`.
- Setiap request Supabase dibungkus `guardRequest` di
  `lib/core/network/api_guard.dart` dengan batas waktu 20 detik. Kegagalan
  jaringan menyalakan `offlineNotifier` (banner "Tidak ada koneksi — data
  mungkin tidak terbaru") dan melempar `JaringanException`. UI memakai
  `pesanKesalahan()` sehingga yang tampil pesan yang bisa dibaca, bukan
  `toString()` mentah.
- Respons 401 atau `PGRST301` memaksa `signOut()` lokal lewat
  `_keluarSesiDiam()`, lalu UI menampilkan "Sesi Anda berakhir. Silakan masuk
  lagi.".
- Pengguna dapat mengubah nama (`updateFullName`), kata sandi
  (`changePassword`, dengan verifikasi sandi lama), dan memilih "Keluar dari
  semua perangkat" (`signOutEverywhere` memakai `SignOutScope.global`) dari
  halaman Profil.
- "Ubah Email" di halaman Profil mengirim tautan konfirmasi ke alamat baru
  lewat `changeEmail`. Email lama tetap aktif sampai tautan tersebut diklik.
- Sesi yang tidak ada interaksi selama 30 menit otomatis diakhiri.
  `SessionIdleWatcher` (`lib/core/widgets/session_idle_watcher.dart`) dipasang
  di `lib/main.dart`, hanya aktif saat pengguna masuk, dan timer direset oleh
  klik/sentuhan (`onPointerDown`) serta saat aplikasi kembali aktif
  (`AppLifecycleState.resumed`).
- Kolom sensitif `profiles` (`role`, `balance`, `total_weight`, `nim`, `email`,
  `id`, `created_at`) dilindungi trigger `profiles_guard_update` yang
  menjalankan `guard_profile_update`. Klien biasa ditolak; admin dan konteks
  server (tanpa JWT, mis. migrasi/SQL editor) tetap boleh.
- Masa berlaku token (JWT expiry, refresh token reuse interval) diatur di
  Dashboard Supabase, bukan di repo. Admin project perlu memeriksa nilainya
  sebelum rilis.

## Hapus Akun

Halaman Profil punya menu "Hapus Akun". Pengguna wajib mengetik `HAPUS` untuk
mengaktifkan tombol konfirmasi, lalu aplikasi memanggil RPC
`hapus_akun_sendiri()` dan logout ke `/login` setelah berhasil.

Akun tidak dihapus barisnya, hanya ditandai:

- `profiles.deleted_at` diisi, `full_name` menjadi `Akun dihapus`, serta `nim`
  dan `email` dikosongkan.
- Semua baris `auth.sessions` pengguna dihapus dan
  `auth.users.banned_until` di-set `infinity`, sehingga login berikutnya
  diblokir.

Riwayat setoran dan penarikan **tidak dihapus** karena FK
`transactions.mahasiswa_id` dan `withdrawals.mahasiswa_id` memakai
`ON DELETE CASCADE`; menghapus baris `auth.users` akan ikut menghapus riwayat
audit.

RPC menolak dengan pesan Indonesia bila `available_balance` masih lebih dari
nol ("Saldo masih ada. Tarik saldo sampai nol sebelum menghapus akun.") atau
masih ada transaksi/penarikan PENDING ("Masih ada pengajuan yang belum
selesai. Tunggu validasi admin.").

Pengecualian trigger `guard_profile_update` hanya aktif di dalam fungsi
`hapus_akun_sendiri()`, yang memanggil
`set_config('sibas.hapus_akun', 'on', true)`. Nilai itu berlaku lokal untuk
transaksi fungsi tersebut, jadi klien tidak bisa memalsukannya lewat update
biasa.

Pemulihan tidak tersedia di aplikasi. Admin harus membuka Dashboard Supabase
dan menghapus `banned_until` pada `auth.users` serta flag `deleted_at` pada
`profiles` bila akun memang perlu dipulihkan.

## Pusat Informasi

Kontak admin resmi ditampilkan di Pusat Informasi
(`lib/features/info/presentation/screens/info_screen.dart`): nomor
`+62 813-8902-1668` dengan tombol salin (nilai yang disalin
`081389021668`). Email, lokasi, dan jam layanan dibaca dari `app_settings`
lewat `appSettingsProvider`; bila kosong/gagal dimuat tampil "Belum diatur".
Admin mengisinya di **Pengaturan Aplikasi** (`/admin/settings`).

## Data Mahasiswa & Pengaturan Aplikasi

Admin punya dua layar operasional:

- **Data Mahasiswa** (`/admin/students`) — daftar akun role `mahasiswa` dari
  `profiles` (RLS `profiles_select` mengizinkan admin membaca semua profil),
  pencarian lokal nama/NIM/email/WA lewat `saringMahasiswa`, dan detail akun.
  Layar ini baca-saja; perubahan data akun tidak dilakukan dari aplikasi.
- **Pengaturan Aplikasi** (`/admin/settings`) — `qr_ttl_minutes` (5–1440,
  default 120) dan kontak admin (email, lokasi, jam layanan). Disimpan ke
  `app_settings` lewat RPC `update_app_settings`; hanya admin. Perubahan TTL
  berlaku untuk pengajuan setoran baru, QR yang sudah terbit tidak berubah.

Keduanya dibuka dari kartu menu di layar **Kelola Jenis Sampah** dan
menggunakan route top-level (tanpa bottom navigation), sama seperti layar
detail admin lain.

## Reset Sandi & QR Penarikan

- Lupa sandi mengirim tautan ke `${origin}/reset-password`
  (`resetPasswordForEmail`); layar atur sandi baru dipaksa lewat
  `passwordRecoveryProvider`. Tautan hanya bekerja bila **Site URL** dan
  **Redirect URLs** di Dashboard Supabase sudah memuat domain aplikasi dan
  SMTP sudah dikonfigurasi. Keduanya langkah dashboard, bukan kode repo.
- Penarikan yang masih PENDING menyimpan `qr_token`; mahasiswa menampilkan QR
  dari layar Tarik atau detail penarikan, admin memindainya di
  `/admin/scan` mode penarikan (`get_withdrawal_by_qr`). Token mentah tidak
  ditampilkan di UI admin.

## Ekspor CSV

Riwayat admin punya menu unduh "Rekap setoran" dan "Rekap penarikan". Builder
ada di `lib/features/verification/data/csv_export.dart`; setoran mengekspor 10
kolom (kode, tanggal, mahasiswa, NIM, jenis sampah, berat, harga/kg, total,
status, alasan ditolak) dan penarikan 7 kolom (ID 8 karakter awal, tanggal,
mahasiswa, NIM, jumlah, status, alasan ditolak). Di web file `.csv` terunduh;
di Android isi CSV disalin ke papan klip dan UI memberi pesan "CSV disalin ke
papan klip". Ekspor setoran mengikuti filter status/tanggal yang sedang tampil.

## Pemindai QR

`/admin/scan` memakai `mobile_scanner` 5.x di Android dan web (kamera
peramban, izin diminta saat layar dibuka). Bila kamera gagal/izin ditolak,
layar menampilkan panel info, input kode QR manual, dan unggah gambar QR dari
galeri. Tombol senter hanya muncul di Android/iOS.

## Penanganan Error & Cache

- `FlutterError.onError`, `PlatformDispatcher.instance.onError`, dan
  `ErrorWidget.builder` dipasang di `lib/main.dart`. Exception tak tertangkap
  dicatat ke konsol, dikirim best-effort lewat `laporkanKesalahan`, dan widget
  gagal menampilkan pesan, bukan layar putih.
- `sessionEpochProvider` naik pada login, logout, dan event `signedOut` dari
  `onAuthStateChange` (termasuk token kedaluwarsa atau logout di perangkat
  lain). Provider data yang bergantung padanya (riwayat, penarikan,
  verifikasi) membuang cache agar data akun sebelumnya tidak terbawa.
- Header cache di `web/vercel.json`: `index.html`, `flutter_bootstrap.js`, dan
  `main.dart.js` memakai `no-cache, must-revalidate`; `/assets/*` dan
  `/canvaskit/*` memakai `max-age=31536000, immutable`. Saat service worker
  menemukan versi baru, `web/index.html` menampilkan banner "Versi baru SIBAS
  tersedia.".
- `test/api_guard_test.dart` menguji `guardRequest` dan `pesanKesalahan`
  (timeout, status offline, pemetaan pesan, penyamaran pesan teknis).
- `test/pengaturan_app_test.dart` menguji validasi TTL/email/teks dan parser
  `AppSettingsModel`; `test/student_filter_test.dart` menguji pencarian
  mahasiswa dan fallback `StudentModel`.
- Telemetri error klien memakai tabel `client_error_logs` dan RPC
  `log_client_error(p_pesan, p_detail, p_platform, p_versi)`. RLS aktif tanpa
  policy baca/tulis untuk klien; akses langsung `anon`/`authenticated` dicabut
  dan hanya RPC `security definer` yang boleh menulis. RPC membatasi maksimal
  20 catatan per pengguna (atau anon) per jam. Pelaporan bersifat best-effort
  dan tidak mencatat `JaringanException`/`SesiBerakhirException`.

## RPC

Semua penulisan transaksi/saldo lewat RPC `security definer`, bukan langsung
dari klien. `expire_stale_transactions()` hanya untuk `service_role` (cron).
Tabel berikut memuat 15 RPC aplikasi yang benar-benar ada di migration;
`handle_new_user()` dan `guard_profile_update()` adalah fungsi trigger, bukan
RPC yang dipanggil klien.

| RPC | Keterangan |
| --- | --- |
| `create_deposit(p_trash_type_id uuid, p_weight numeric)` | Buat setoran PENDING + QR sesuai `qr_ttl_minutes` (default 120 menit) |
| `get_transaction_by_qr(p_code text)` | Cari transaksi dari token/id QR (admin) |
| `approve_transaction(p_transaction_id uuid)` | Setujui setoran, tambah saldo & berat |
| `reject_transaction(p_transaction_id uuid, p_reason text)` | Tolak setoran + alasan |
| `expire_stale_transactions()` | Tandai PENDING yang QR-nya lewat sebagai EXPIRED |
| `create_withdrawal(p_amount numeric)` | Ajukan penarikan saldo |
| `approve_withdrawal(p_withdrawal_id uuid)` | Setujui penarikan, potong saldo |
| `reject_withdrawal(p_withdrawal_id uuid, p_reason text)` | Tolak penarikan + alasan |
| `is_admin()` | Cek role pemanggil |
| `available_balance(p_user uuid)` | Saldo dikurangi penarikan PENDING |
| `admin_metrics()` | Metrik dashboard admin: total berat APPROVED dan jumlah per status (JSON) |
| `log_client_error(p_pesan text, p_detail text, p_platform text, p_versi text)` | Catat error klien, maksimal 20 per pengguna/anon per jam |
| `hapus_akun_sendiri()` | Tandai akun terhapus, anonimkan identitas, cabut sesi, blokir login |
| `get_app_settings()` | Baca `qr_ttl_minutes` dan kontak admin (satu baris `app_settings`) |
| `update_app_settings(p_qr_ttl_minutes integer, p_contact_email text, p_contact_location text, p_contact_hours text)` | Ubah pengaturan global; hanya admin, TTL 5–1440 menit, email divalidasi |

Tabel: `profiles`, `trash_types`, `transactions`, `transaction_audits`,
`withdrawals`, `client_error_logs`, `app_settings`. Schema hanya diubah lewat
migration baru di `supabase/migrations/`.

## Verifikasi

Tidak ada SDK Flutter lokal, jadi kebenaran kode dibuktikan lewat GitHub
Actions, bukan klaim lokal:

- **Analyze & Test** (`.github/workflows/analyze.yml`) — jalan di setiap PR ke
  `main`: `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test`.
- **Build Android APK & Deploy Web to Vercel**
  (`.github/workflows/build-apk.yml`) — PR menghasilkan preview Vercel; push ke
  `main` menghasilkan deploy produksi dan artifact APK.

```bash
gh run list --branch <branch> --limit 5
gh run watch <run-id> --exit-status
gh run view <run-id> --log-failed
```

## Keterbatasan

- Flutter dipin `3.47.7` di kedua workflow karena `lib/` memakai
  `withValues(alpha:)`. Jangan hapus pin tanpa menyesuaikan seluruh kode.
- Deploy produksi Vercel hanya dari `push` ke `main`; PR hanya preview.
- Uji yang ada baru unit test; belum ada widget/integration test. Uji kamera
  dan PWA di perangkat nyata (Android/iOS/Windows) belum dilakukan dari repo.
- Site URL Supabase, Redirect URL `https://sibas.vercel.app/reset-password`,
  dan SMTP belum diatur di dashboard; reset/verifikasi email belum andal
  sampai langkah dashboard itu selesai.
- iOS belum ada (`ios/` tidak dibuat) karena mesin pengembangan tidak punya
  Flutter SDK; target rilis saat ini Android + web.
- Bila `ANDROID_KEYSTORE_BASE64` kosong, APK CI memakai debug key dan tidak
  bisa di-update di atas versi lama. Buat keystore rilis dan isi secrets
  (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`) sebelum distribusi.
- Tidak ada pemulihan akun dari aplikasi (harus lewat Dashboard Supabase) dan
  belum ada push notification.
- Layar Data Mahasiswa bersifat baca-saja; koreksi data akun dilakukan lewat
  Dashboard Supabase.
