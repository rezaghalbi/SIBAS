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

Direktori `test/` belum ada; `flutter test` tidak menjalankan apa pun.

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

## RPC

Semua penulisan transaksi/saldo lewat RPC `security definer`, bukan langsung
dari klien. `expire_stale_transactions()` hanya untuk `service_role` (cron).

| RPC | Keterangan |
| --- | --- |
| `create_deposit(p_trash_type_id uuid, p_weight numeric)` | Buat setoran PENDING + QR 2 jam |
| `get_transaction_by_qr(p_code text)` | Cari transaksi dari token/id QR (admin) |
| `approve_transaction(p_transaction_id uuid)` | Setujui setoran, tambah saldo & berat |
| `reject_transaction(p_transaction_id uuid, p_reason text)` | Tolak setoran + alasan |
| `expire_stale_transactions()` | Tandai PENDING yang QR-nya lewat sebagai EXPIRED |
| `create_withdrawal(p_amount numeric)` | Ajukan penarikan saldo |
| `approve_withdrawal(p_withdrawal_id uuid)` | Setujui penarikan, potong saldo |
| `reject_withdrawal(p_withdrawal_id uuid, p_reason text)` | Tolak penarikan + alasan |
| `is_admin()` | Cek role pemanggil |
| `available_balance(p_user uuid)` | Saldo dikurangi penarikan PENDING |

Tabel: `profiles`, `trash_types`, `transactions`, `transaction_audits`,
`withdrawals`. Schema hanya diubah lewat migration baru di
`supabase/migrations/`.

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

- Logo masih placeholder 1x1 px (`assets/images/logo_sibas.png`); ganti dengan
  aset asli sebelum rilis.
- Flutter dipin `3.47.7` di kedua workflow karena `lib/` memakai
  `withValues(alpha:)`. Jangan hapus pin tanpa menyesuaikan seluruh kode.
- Deploy produksi Vercel hanya dari `push` ke `main`; PR hanya preview.
- Belum ada test otomatis (tidak ada direktori `test/`) dan job pg_cron perlu
  pg_cron aktif di project Supabase.
