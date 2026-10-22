# RENCANA EKSEKUSI SIBAS

Sistem Informasi Bank Sampah — Poltekkes Kemenkes Yogyakarta
Stack: Flutter (mobile + web PWA) · Supabase (Auth, Postgres, RPC) · Riverpod · GoRouter

Disusun: 22 Oktober 2026
Status: rencana, belum ada perubahan kode.

---

## 0. Ringkasan Temuan Analisis

### 0.1 Sumber acuan dan urutan prioritas

| Prioritas | Sumber | Isi | Catatan |
|---|---|---|---|
| 1 | `reference/APP FITUR.docx` | Spesifikasi fungsional + aturan bisnis + palet resmi | Mengikat. Alur transaksi tidak boleh diubah. |
| 2 | `AGENTS.md` | Stack, Clean Architecture + feature-first, tema Apple Glassmorphism | Mengikat untuk arsitektur & gaya UI. |
| 3 | `reference/bank-sampah-poltekk.html` | Wireframe visual (demo localStorage) | Acuan **visual** saja, bukan acuan fungsi. |

### 0.2 Kondisi kode saat ini

Struktur feature-first sudah ada dan konsisten:

```
lib/core/{constants,network,router,utils,widgets}
lib/features/auth/{data,domain,presentation}
lib/features/dashboard/presentation
lib/features/deposit/{data,domain,presentation}
lib/features/history/{data,domain,presentation}
lib/features/verification/{data,domain,presentation}
```

Namun aplikasi **belum dapat dikompilasi**. Temuan kritis:

1. **`lib/features/verification/data/verification_repository.dart` rusak.** File diawali karakter `"` liar dan terpotong setelah `getAdminMetrics()`. Empat method yang dipakai layar tidak ada:
   - `getAllTransactions(...)`
   - `getTransactionForVerification(...)`
   - `approveTransaction(...)`
   - `rejectTransaction(...)`
   Pemanggilnya: `verification_provider.dart:25`, `admin_scan_screen.dart:39`, `verification_bottom_sheet.dart:90,139`.
2. **Tidak ada artefak backend di repo**: tidak ada folder `supabase/`, migrasi SQL, seed, maupun RPC. Semua repository memanggil tabel yang belum terbukti ada (`profiles`, `trash_types`, `transactions`).
3. **Aset logo placeholder.** `assets/images/logo_sibas.png`, `web/favicon.png`, `web/icons/Icon-192.png` semuanya PNG 1×1 piksel.
4. **Flutter SDK tidak terpasang** di mesin ini (`flutter`, `dart`, `fvm` tidak ditemukan), sehingga `flutter analyze` belum bisa dijalankan.
5. **Tidak ada test**, tidak ada `README`, tidak ada contoh env; kredensial hanya lewat `--dart-define`.

### 0.3 Pelanggaran spesifikasi yang harus diperbaiki

| # | Temuan | Lokasi | Dampak |
|---|---|---|---|
| 1 | Registrasi publik bisa memilih role `admin` | `register_screen.dart` (`_currentRole`), `auth_repository.signUp` | Eskalasi hak akses. Role admin wajib dibuat manual/seed. |
| 2 | Setoran gagal tetap dianggap sukses (dibuat ID lokal `tx_<epoch>`) | `deposit_repository.createDepositTransaction` catch block | Melanggar "jangan mengklaim berhasil sebelum server konfirmasi". |
| 3 | Harga kategori hardcoded (Rp 2.500, 1.800, dst.) sebagai fallback | `deposit_repository.defaultCategories` | Melanggar "jangan mengarang harga resmi". |
| 4 | QR hanya countdown lokal; kedaluwarsa tidak divalidasi server | `qr_display_screen.dart` | QR kedaluwarsa masih bisa diproses admin. |
| 5 | QR berisi UUID transaksi mentah tanpa scoping | `qr_display_screen.dart`, `deposit_repository.getTransactionById` | Tidak ada validasi pemilik; user bisa membuka ID transaksi lain. |
| 6 | Admin dapat mengubah berat saat menyetujui | `verification_bottom_sheet.dart` (`_weightController`) | DOCX: berat yang ditampilkan adalah berat pengajuan; jangan ubah diam-diam. |
| 7 | Persetujuan tidak mencatat `verified_at` / identitas verifikator di UI & model | `transaction_model.dart`, bottom sheet | DOCX mewajibkan jejak verifikasi. |
| 8 | Belum ada tabel audit perubahan status | — | DOCX butuh audit trail. |
| 9 | `hasActiveRate: true` hardcoded | `dashboard_screen.dart` | Menampilkan "Rp 0" palsu saat tarif belum aktif. |
| 10 | Label status "Menunggu Validasi" | `status_badge.dart`, `status_helper.dart` | DOCX menetapkan "Menunggu Verifikasi". |
| 11 | Palet kode `#095C3B/#0E7A4F/#2FA56F` | `colors.dart` | DOCX menetapkan `#005746/#16865D/#9BD84A`. (`web/index.html`, manifest ikut salah.) |
| 12 | Tidak ada lapisan glassmorphism | seluruh widget | `AGENTS.md` mewajibkan `BackdropFilter` blur 12, border putih 0.2, radius 16–24. |
| 13 | Navigasi belum lengkap | `app_router.dart` | Tidak ada bottom nav; tidak ada Profil, Pengajuan Admin, Kelola Jenis Sampah & Tarif, Detail Transaksi. |
| 14 | Halaman mahasiswa memakai `context.push` tanpa shell | dashboard/history | Back stack menumpuk; pola navigasi tidak konsisten. |
| 15 | `refreshListenable: ValueNotifier(authState)` dibuat ulang tiap rebuild | `app_router.dart` | Router berpotensi reset; `authStateStreamProvider` tidak terpakai. |

### 0.4 Konflik acuan yang perlu keputusan

| Hal | DOCX | Wireframe HTML | Keputusan |
|---|---|---|---|
| Warna primer | `#005746` | `#0E7A4F` | **DOCX final**: `#005746`, `#16865D`, `#9BD84A`; web/manifest diselaraskan. |
| Input berat | Mahasiswa input manual (wajib) | Tidak ada field berat; "berat final ditimbang petugas" | Ikuti DOCX: input manual, admin **tidak** mengubah. |
| Tarik saldo | Tidak ada | Ada | **Ikut wireframe**: pengajuan penarikan + persetujuan admin. |
| Notifikasi & Pusat Informasi | Tidak ada | Ada | **Ikut wireframe**: notifikasi in-app dan layar info kontak. |
| Label navigasi | Beranda, Setor, Riwayat, Profil | Beranda, Setor, Saldo, Info, Profil | Ikuti wireframe: Beranda, Setor, Saldo, Info, Profil. Riwayat tetap dapat diakses dari Beranda/Saldo. |
| Font | tidak ditentukan | Plus Jakarta Sans | Pertahankan Plus Jakarta Sans. |

---

## 1. Modul dan Fitur Utama (berdasarkan DOCX)

### 1.1 Autentikasi & Otorisasi
- Login email + password untuk mahasiswa dan admin.
- Logout + konfirmasi.
- Registrasi **mahasiswa saja** (NIM, nama, email). Akun admin dibuat lewat seed/admin existing.
- Guard rute dua arah (mahasiswa ↔ admin) di GoRouter.
- Sesi persisten (Supabase Auth) dan redirect otomatis.
- Hak akses ditegakkan di server (RLS + RPC `SECURITY DEFINER`), bukan hanya di UI.

### 1.2 Dashboard Mahasiswa
- Sapaan + nama + NIM.
- Kartu saldo (hanya jika tarif aktif) dan total berat disetujui.
- Tombol utama Setor Sampah.
- Ringkasan 5 transaksi terbaru + badge status.
- Chip "N pengajuan menunggu verifikasi".
- Bottom navigation: Beranda, Setor, Riwayat, Profil.
- Empty, loading, error state.

### 1.3 Pengajuan Setoran (Mahasiswa)
- Pilih jenis sampah dari `trash_types` aktif.
- Input berat manual (angka > 0, satuan kg, dukung koma/titik).
- Estimasi nilai = berat × tarif, ditandai "estimasi" dan hanya jika tarif > 0.
- Validasi form; tombol "Ajukan Setoran".
- Sukses → transaksi tersimpan di server → QR muncul. Gagal → pesan, tidak ada QR.

### 1.4 QR Transaksi
- QR otomatis per transaksi, unik, dibuat sistem (bukan admin).
- Isi QR: token acak non-sensitif (bukan UUID mentah, bukan password/token auth).
- TTL 2 jam, dapat dikonfigurasi; **validasi kedaluwarsa di server**.
- Layar QR: nomor transaksi, nama, jenis, berat, waktu, status, hitung mundur, petunjuk.
- Status terminal (Disetujui/Ditolak/Kedaluwarsa) → QR di-watermark dan tidak dapat dipakai lagi.

### 1.5 Verifikasi Admin
- Scan kamera (`mobile_scanner`) + fallback unggah gambar + input kode manual.
- Setelah scan: tampilkan nomor, identitas mahasiswa, jenis, berat pengajuan, estimasi, waktu, status.
- Setujui → RPC atomik: cek role, cek status PENDING, cek `qr_expires_at`, update status, `verified_at`, `verified_by`, tambah `total_weight` + saldo **sekali**.
- Tolak → wajib alasan; saldo/berat tidak berubah; alasan tersimpan.
- QR kedaluwarsa / sudah diproses → pesan jelas, tidak ada perubahan data.

### 1.6 Dashboard Admin
- Metrik: menunggu, disetujui, ditolak, total berat disetujui.
- Daftar pengajuan terbaru.
- Pencarian (nama/NIM/ID) + filter status + filter tanggal.
- Pintasan ke pemindai QR dan riwayat verifikasi.

### 1.7 Riwayat & Detail Transaksi
- Mahasiswa: hanya transaksi miliknya, filter status.
- Admin: semua transaksi sesuai hak akses, filter status/tanggal, pencarian.
- Detail memuat seluruh field DOCX §8, termasuk `verified_at`, admin verifikator, alasan penolakan.

### 1.8 Pengelolaan Data Master (Admin)
- CRUD jenis sampah + tarif per kg + status aktif.
- Daftar mahasiswa (read-only minimal: nama, NIM, total berat).
- Tarif kosong/0 → fitur rupiah nonaktif, UI hanya menampilkan kg.

### 1.9 PWA & Lintas Platform
- `manifest.webmanifest` valid, ikon 192/512 + maskable, `start_url`, `scope`, `theme_color`, `background_color`.
- Service worker cache aset UI saja; transaksi wajib online.
- Ikon Apple touch, meta iOS, dan penanganan instalasi per platform (tanpa klaim seragam).
- Uji Android Chrome, iOS Safari, Windows Chrome/Edge.

### 1.10 Fitur Tambahan (mengikuti wireframe)
Keputusan: diimplementasikan, tetapi tidak boleh mengganggu alur wajib DOCX.

**Tarik Saldo**
- Mahasiswa mengajukan nominal penarikan (Rp, bulat, > 0).
- Saldo tersedia = `balance` − total penarikan PENDING.
- Penarikan PENDING tidak mengurangi `balance`; saldo dipotong hanya saat admin menyetujui.
- Admin menyetujui/menolak lewat tab "Penarikan" di Pengajuan; tolak wajib alasan.
- Jika `balance` tidak mencukupi saat approve → tolak dengan pesan jelas.
- Semua perubahan saldo lewat RPC, bukan update langsung.
- Fitur ini hanya tampil jika tarif rupiah aktif; jika tarif 0, menu tarik disembunyikan.

**Notifikasi**
- Ikon lonceng + badge jumlah di Beranda mahasiswa.
- Isi diturunkan dari data transaksi (PENDING/APPROVED/REJECTED/EXPIRED) dan penarikan; **tanpa tabel baru**.
- Bottom sheet daftar notifikasi; item menuju detail terkait; tanpa state baca-persisten.

**Pusat Informasi**
- Layar statis: telepon admin, WhatsApp, email, tautan formulir pengaduan, catatan 1×24 jam.
- Kontak dikonfigurasi sebagai konstanta; tanpa backend.

---

## 2. Rancangan Data & Aturan Server

### 2.1 Skema minimum

```sql
-- profiles: 1-1 dengan auth.users
profiles(
  id uuid pk references auth.users on delete cascade,
  email text, full_name text, nim text unique, role text check (role in ('mahasiswa','admin')),
  balance numeric default 0, total_weight numeric default 0, created_at timestamptz default now()
)

trash_types(
  id uuid pk default gen_random_uuid(),
  name text not null, unit text default 'kg',
  price_per_kg numeric default 0 check (price_per_kg >= 0),
  description text, is_active boolean default true, created_at timestamptz default now()
)

transactions(
  id uuid pk default gen_random_uuid(),
  tx_code text unique not null,              -- nomor tampil, mis. BS-2026-0001
  qr_token text unique not null,             -- isi QR (acak, non-sensitif)
  mahasiswa_id uuid not null references profiles(id),
  trash_type_id uuid not null references trash_types(id),
  weight numeric not null check (weight > 0),
  price_per_kg_snapshot numeric not null default 0,  -- tarif saat diajukan
  estimated_amount numeric default 0,
  final_amount numeric,
  status text not null default 'PENDING'
    check (status in ('PENDING','APPROVED','REJECTED','EXPIRED')),
  rejection_reason text,
  verified_by uuid references profiles(id),
  verified_at timestamptz,
  qr_expires_at timestamptz not null default now() + interval '2 hours',
  created_at timestamptz default now()
)

transaction_audits(
  id bigserial pk,
  transaction_id uuid references transactions(id),
  actor_id uuid references profiles(id),
  from_status text, to_status text,
  note text, created_at timestamptz default now()
)

withdrawals(
  id uuid pk default gen_random_uuid(),
  mahasiswa_id uuid not null references profiles(id),
  amount numeric not null check (amount > 0),
  status text not null default 'PENDING'
    check (status in ('PENDING','APPROVED','REJECTED')),
  rejection_reason text,
  verified_by uuid references profiles(id),
  verified_at timestamptz,
  created_at timestamptz default now()
)
```

Aturan tambahan:
- `final_amount` dihitung server: `weight * price_per_kg_snapshot`.
- Index: `transactions(mahasiswa_id, created_at desc)`, `transactions(status)`, `transactions(qr_token)`, `withdrawals(mahasiswa_id, status)`.
- Tidak ada kolom saldo yang boleh ditulis klien; `profiles.balance/total_weight` hanya lewat RPC.
- Penarikan PENDING tidak memotong `balance`; pemotongan terjadi di `approve_withdrawal`.

### 2.2 RPC wajib

| RPC | Perilaku |
|---|---|
| `create_deposit(p_trash_type_id, p_weight)` | Validasi auth mahasiswa, berat > 0, jenis aktif; hitung tarif snapshot; buat `tx_code` + `qr_token`; set expiry; kembalikan baris transaksi. |
| `get_transaction_by_qr(p_token)` | Hanya admin; cari transaksi berdasarkan `qr_token`; kembalikan detail + profil + jenis; tolak jika tidak ada. |
| `approve_transaction(p_transaction_id)` | `SELECT ... FOR UPDATE`; tolak jika bukan admin, status ≠ PENDING, atau `now() > qr_expires_at` (set EXPIRED + audit); update APPROVED, `verified_*`, tambah berat/saldo **sekali**; tulis audit. |
| `reject_transaction(p_transaction_id, p_reason)` | Sama, reason wajib; tidak mengubah saldo/berat; audit. |
| `expire_stale_transactions()` | Job/manual: PENDING yang lewat TTL → EXPIRED + audit. |
| `create_withdrawal(p_amount)` | Mahasiswa; amount > 0; `amount <= balance - sum(PENDING withdrawals)`; buat PENDING. |
| `approve_withdrawal(p_id)` | Admin; lock baris + profil; tolak jika status ≠ PENDING atau saldo < amount; kurangi saldo **sekali**; set APPROVED. |
| `reject_withdrawal(p_id, p_reason)` | Admin; alasan wajib; saldo tidak berubah. |

### 2.3 RLS ringkas
- `profiles`: user baca profil sendiri; admin baca semua; update hanya `full_name/nim` milik sendiri; `role/balance/total_weight` tidak dapat diubah klien.
- `trash_types`: semua authenticated baca yang aktif; admin penuh.
- `transactions`: mahasiswa `select` hanya `mahasiswa_id = auth.uid()`; admin `select` semua; **tidak ada** insert/update/delete langsung dari klien (hanya RPC).
- `transaction_audits`: admin baca; insert hanya via RPC.
- `withdrawals`: mahasiswa `select` miliknya; admin `select` semua; tulis hanya via RPC.

### 2.4 Seed
- 1 admin, 2 mahasiswa demo, 5 jenis sampah dengan tarif contoh yang **ditandai data demo**.
- Akun demo didokumentasikan di README, bukan di UI produksi.

---

## 3. Komponen UI — Apple Glassmorphism

Semua komponen baru/refactor mengikuti `AGENTS.md`:

- `BackdropFilter(ImageFilter.blur(sigmaX: 12, sigmaY: 12))`.
- Fill gradien `Colors.white.withValues(alpha: 0.15)` → `0.05` (light) / setara gelap.
- Border `Colors.white.withValues(alpha: 0.2)`, width 1.2.
- Radius 16 / 20 / 24; shadow blur 20–30, opacity 0.05–0.1.
- Kontras teks dijaga (di atas hero gelap gunakan putih ≥ 0.85; di atas kartu terang gunakan `textPrimary`).
- Hormati `MediaQuery.disableAnimations` dan sediakan fallback tanpa blur untuk perangkat low-end (`ponytail:` komentar di widget kaca).

### 3.1 Design token (`lib/core/constants`)
- `colors.dart`: selaraskan ke `#005746`, `#16865D`, `#9BD84A`, `#FFFFFF`; pertahankan token status.
- `theme.dart`: tambah `glass*` token (blur sigma, fill, border, radius, shadow).
- `app_spacing.dart` (baru, kecil): skala 4/8/12/16/20/24 bila dibutuhkan; hindari abstraksi berlebih.

### 3.2 Widget bersama (`lib/core/widgets`)
| Widget | Fungsi |
|---|---|
| `glass_card.dart` | Pembungkus blur + border + radius + shadow; parameter `padding`, `radius`, `tint`. |
| `glass_scaffold.dart` | Background gradien lembut + lapisan blob, tempat semua layar. |
| `app_bottom_nav.dart` | Bottom nav kaca, 4 item mahasiswa / 4 item admin, badge jumlah pending. |
| `app_top_bar.dart` | Top bar kaca dengan judul, subtitle, aksi, tombol kembali. |
| `status_badge.dart` | Refactor: label "Menunggu Verifikasi", dukung 4 status + ukuran small. |
| `tx_list_item.dart` | Refactor ke kaca, tambah NIM (mode admin) dan waktu verifikasi opsional. |
| `empty_state.dart` | Ikon + judul + deskripsi + aksi opsional. |
| `error_state.dart` | Pesan ramah + tombol "Coba Lagi" (pemetaan error jaringan/kamera). |
| `loading_overlay.dart` | Indikator blokir saat submit. |
| `confirm_dialog.dart` | Konfirmasi aksi penting (approve/reject/logout). |
| `metric_card.dart` | Kartu metrik admin. |
| `qr_frame.dart` | Bingkai QR + watermark status terminal. |
| `notification_sheet.dart` | Bottom sheet notifikasi turunan data transaksi/penarikan. |

### 3.3 Layar
| Layar | Status | Aksi |
|---|---|---|
| `login_screen` | ada | Refactor kaca; hapus tab role (role ditentukan server); error mapping. |
| `register_screen` | ada | Kaca; hapus opsi admin; tambah konfirmasi password. |
| `dashboard_screen` | ada | Ganti hero solid → hero gradien + kartu kaca; bottom nav; sembunyikan rupiah jika tarif 0. |
| `setor_screen` | ada | Kaca; grid jenis → list kartu kaca; validasi; tanpa fallback palsu. |
| `qr_display_screen` | ada | Kaca; render QR dari `qr_token`; expiry dari server; watermark; tombol salin kode. |
| `history_screen` | ada | Kaca; filter chip; tarik-untuk-refresh; buka detail. |
| `saldo_screen` | **baru** | Kartu saldo besar, tombol Tarik Saldo, filter & daftar riwayat; hanya jika tarif aktif. |
| `withdraw_sheet` | **baru** | Input nominal, validasi saldo tersedia, konfirmasi pengajuan. |
| `notification_sheet` | **baru** | Daftar notifikasi + tautan ke detail. |
| `info_screen` | **baru** | Kontak admin, WhatsApp, email, formulir pengaduan, catatan 1×24 jam. |
| `transaction_detail_screen` | **baru** | Detail lengkap + alasan/verifikator/waktu. |
| `profile_screen` | **baru** | Data akun, NIM, total berat, logout. |
| `admin_dashboard_screen` | ada | Kaca; metrik; daftar pending; filter status/tanggal; bottom nav admin. |
| `admin_scan_screen` | ada | Kaca di area kontrol; izin kamera; fallback galeri/manual; state error jelas. |
| `admin_submissions_screen` | **baru** | Segmen Setoran / Penarikan + aksi approve/reject. |
| `admin_history_screen` | ada | Kaca + filter tanggal; detail verifikasi. |
| `trash_type_management_screen` | **baru** | CRUD jenis & tarif (admin). |
| `verification_sheet` | ada | Hapus input berat; tampilkan berat pengajuan read-only; wajib alasan saat tolak; konfirmasi. |

---

## 4. Roadmap Pengerjaan

Prinsip: perbaiki fondasi → backend → tema → alur mahasiswa → alur admin → PWA & pengujian.
Setiap fase berakhir dengan `flutter analyze` bersih dan aplikasi dapat dijalankan.

### Fase 0 — Stabilisasi & Fondasi (blocker, 1–2 hari)
1. Pulihkan `verification_repository.dart` (tulis ulang dari commit `44cf801`, lalu sesuaikan ke RPC baru).
2. Pastikan proyek compile: `flutter pub get`, `flutter analyze`.
3. Minta logo SIBAS asli (≥512×512) + ikon turunan; ganti placeholder 1×1.
4. Tambah `README.md` (setup, `--dart-define`, akun demo, batasan) dan `.env.example`.
5. Tambah skrip analisis di CI (`flutter analyze --fatal-infos` setelah bersih).

**Exit:** `flutter analyze` tanpa error; login tampil; tidak ada aset 1×1.

### Fase 1 — Backend Supabase (2–3 hari)
1. `supabase/migrations/0001_init.sql`: tabel, index, constraint, trigger `profiles` dari `auth.users`.
2. `0002_rls.sql`: seluruh policy.
3. `0003_rpc.sql`: `create_deposit`, `get_transaction_by_qr`, `approve_transaction`, `reject_transaction`, `expire_stale_transactions`, `create_withdrawal`, `approve_withdrawal`, `reject_withdrawal`.
4. `0004_seed.sql`: admin + mahasiswa demo + jenis sampah demo.
5. Uji RPC via SQL: approve dua kali → gagal; QR kedaluwarsa → gagal; mahasiswa approve → gagal; reject → saldo tetap; penarikan melebihi saldo → gagal.
6. Dokumentasikan variabel lingkungan dan cara migrasi.

**Exit:** skenario §12 DOCX lulus di level database.

### Fase 2 — Design System Glassmorphism (2 hari)
1. Selaraskan token warna DOCX + token kaca di `colors.dart`/`theme.dart`.
2. Buat `glass_card`, `glass_scaffold`, `app_bottom_nav`, `app_top_bar`, `empty_state`, `error_state`, `confirm_dialog`.
3. Refactor `hero_header` & `saldo_hero_card` memakai lapisan kaca; cek kontras dan `disableAnimations`.
4. Halaman contoh (login) sebagai acuan visual; review sebelum menyebar ke layar lain.

**Exit:** satu layar percontohan konsisten dengan `AGENTS.md`; widget lain memakai komponen yang sama.

### Fase 3 — Autentikasi & Routing (1–2 hari)
1. `AuthRepository`: hapus fallback profil fabrikasi; petakan error Supabase ke pesan Indonesia.
2. Registrasi mahasiswa saja; validasi NIM unik; konfirmasi password.
3. `currentUserProvider` → `AsyncNotifier`; sinkronkan `onAuthStateChange` ke router lewat `refreshListenable` yang stabil.
4. Tambah `StatefulShellRoute` + bottom nav; rute baru: `/saldo`, `/info`, `/profile`, `/transaction/:id`, `/admin/submissions`, `/admin/trash-types`.
5. Guard rute dipertahankan; redirect setelah login sesuai role; logout membersihkan state.

**Exit:** login/logout mahasiswa & admin; deep link terlindungi; tidak ada akses lintas role.

### Fase 4 — Alur Mahasiswa (3–4 hari)
1. Dashboard: data dari server, metrik hanya yang disetujui, chip pending, empty state.
2. Setor: kategori dari DB (tanpa fallback harga), berat manual tervalidasi, estimasi jelas, submit via `create_deposit`, tangani offline/gagal.
3. QR: `qr_token`, hitung mundur dari `qr_expires_at` server, watermark, petunjuk, salin kode.
4. Riwayat: filter status, tarik-untuk-refresh, buka detail.
5. Detail transaksi: semua field DOCX §8 termasuk alasan, verifikator, waktu verifikasi.
6. Profil: data akun, total berat, logout.
7. Saldo: kartu saldo besar, riwayat dengan filter, pengajuan tarik saldo (RPC), tampil hanya jika tarif aktif.
8. Notifikasi: ikon + badge + bottom sheet turunan transaksi/penarikan.
9. Pusat Informasi: layar statis kontak & pengaduan.

**Exit:** alur mahasiswa end-to-end berhasil; tidak ada data lokal palsu.

### Fase 5 — Alur Admin (3–4 hari)
1. Dashboard metrik + pencarian + filter status/tanggal + pintasan scan.
2. Pengajuan: segmen Setoran / Penarikan; buka detail; approve/reject via RPC (setoran & penarikan).
3. Scan: izin kamera, fallback unggah/manual, validasi `qr_token`, pesan kedaluwarsa/sudah diproses.
4. Riwayat verifikasi: filter, identitas petugas, waktu; termasuk penarikan.
5. Kelola jenis sampah & tarif: CRUD + aktif/nonaktif; konfirmasi sebelum hapus.
6. Setelah approve/reject: invalidasi provider terkait + umpan balik sukses; saldo & badge notifikasi ikut segar.

**Exit:** approve sekali menambah saldo/berat tepat satu kali; reject tidak mengubah; QR terminal tidak dapat diproses ulang; approve penarikan memotong saldo tepat sekali.

### Fase 6 — PWA, Pengujian, Dokumentasi (2–3 hari)
1. Manifest + ikon 192/512/maskable + apple-touch-icon; `scope`, `start_url`, warna DOCX.
2. Service worker: cache aset UI; jangan cache respons transaksi.
3. Uji matriks §12 DOCX + §14G (Android Chrome, iOS Safari, Windows Chrome/Edge).
4. Tambah widget/unit test untuk `TransactionStatusHelper`, validasi berat, dan pemetaan error.
5. Dokumentasi alur mahasiswa/admin, hasil uji nyata, daftar keterbatasan.
6. Deploy web (Vercel) + APK; verifikasi HTTPS dan izin kamera.

**Exit:** semua skenario wajib lulus atau didokumentasikan sebagai keterbatasan; tidak ada klaim tanpa bukti uji.

---

## 5. Matriks Pengujian Wajib (DOCX §12)

| # | Skenario | Level | Ekspektasi |
|---|---|---|---|
| 1 | Mahasiswa ajukan setoran berat manual | UI + DB | Baris PENDING dibuat, `qr_token` unik |
| 2 | QR muncul setelah simpan sukses | UI | QR hanya tampil bila server mengembalikan baris |
| 3 | Admin scan QR | UI + RPC | Data transaksi yang benar ditampilkan |
| 4 | Approve | DB | Saldo & berat bertambah tepat 1× |
| 5 | Approve ganda | DB | Ditolak, tanpa perubahan |
| 6 | Reject | DB | Saldo & berat tetap, alasan tersimpan |
| 7 | QR kedaluwarsa | DB | Ditolak, status EXPIRED + audit |
| 8 | QR sudah diproses | DB | Ditolak |
| 9 | Mahasiswa approve | DB | Ditolak oleh cek role |
| 10 | Mahasiswa lihat transaksi orang lain | DB | 0 baris (RLS) |
| 11 | Jaringan/kamera gagal | UI | Pesan jelas, tidak ada klaim sukses |
| 12 | Tarif 0 | UI | Rupiah disembunyikan |
| 13 | Berbagai ukuran layar | UI | Tidak ada elemen terpotong |
| 14 | Offline saat submit | UI | Gagal eksplisit, tanpa QR |
| 15 | Pengajuan tarik saldo > saldo tersedia | DB | Ditolak |
| 16 | Approve penarikan | DB | Saldo berkurang tepat 1×; approve ganda gagal |
| 17 | Reject penarikan | DB | Saldo tetap, alasan tersimpan |

---

## 6. Risiko & Keputusan yang Dibutuhkan

1. **Logo asli belum tersedia** — semua aset 1×1. Perlu file resmi sebelum Fase 0 selesai.
2. **Flutter SDK tidak ada di mesin ini** — perlu instalasi atau arahkan ke SDK yang ada agar `flutter analyze` dapat dijalankan.
3. **Kredensial Supabase** — perlu URL + anon key untuk uji nyata; jangan commit.
4. **Palet** — keputusan: DOCX `#005746`/`#16865D`/`#9BD84A`; wireframe, `web/index.html`, dan manifest wajib diselaraskan.
5. **Penarikan saldo** — fitur tambahan; hanya aktif jika tarif rupiah aktif. Perlu konfirmasi nominal minimum dan apakah penarikan butuh pencairan tunai manual di luar aplikasi.
6. **Notifikasi** — diturunkan dari data transaksi/penarikan; tidak ada tabel notifikasi, tidak ada status "sudah dibaca". Cukup untuk kebutuhan wireframe; tambah tabel jika butuh push/read-state.
7. **Status "EXPIRED"** bergantung job/akhir permintaan; tanpa cron, expiry dievaluasi saat scan/approve. Rekomendasi: evaluasi saat akses + opsi cron.
8. **Data lama** — jika database produksi sudah berisi baris, migrasi harus aditif dan idempoten.
9. **Kontak Pusat Informasi** — nomor/tautan di wireframe adalah contoh; perlu data kontak resmi sebelum rilis.

---

## 7. Definition of Done

- `flutter analyze` bersih; build web & APK sukses.
- Semua skenario §5 lulus di lingkungan uji nyata.
- Tidak ada fallback data palsu, harga karangan, atau klaim sukses sebelum server konfirmasi.
- Kontrak data & RPC terdokumentasi; RLS aktif.
- Komponen kaca konsisten di seluruh layar; kontras teks lolos pemeriksaan manual.
- README memuat setup, env, akun demo, alur, hasil uji, dan daftar keterbatasan.
