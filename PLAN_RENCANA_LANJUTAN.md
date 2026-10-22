# Rencana Lanjutan SIBAS (revisi 2)

Dokumen kerja. Belum ada kode. Setiap butir dikerjakan sebagai PR terpisah dan
diverifikasi lewat CI (`Analyze & Test`, `Build APK & Web`).

## Keputusan

- Tarik dana: **QR lokal sebagai jalur tambahan**; persetujuan manual dari daftar
  pengajuan **tetap ada**. Uang diserahkan di luar aplikasi.
- Logo jenis sampah: ikon Material default, foto unggahan admin opsional. Tanpa plugin.
- Nomor WhatsApp dikumpulkan sejak **registrasi** dan bisa diedit di profil.
- Keystore & iOS: **ditunda**. Tidak termasuk fase yang dikerjakan sekarang.
- Navigasi harus memuat jalan masuk ke fitur baru (bukan hanya dari dashboard).

## Kondisi awal (fakta kode)

- `profiles`: `id, email, full_name, nim, role, balance, total_weight, created_at, deleted_at`.
  Belum ada `phone`, belum ada `avatar_path`.
- `signUp` hanya mengirim metadata `full_name` dan `nim`; `handle_new_user`
  mengisi `profiles` dari metadata itu.
- `guard_profile_update` menolak perubahan `nim`, `email`, `deleted_at`, dst
  untuk non-admin.
- Bottom nav mahasiswa 4 tab: Beranda, Setor, Riwayat, Profil. Saldo dan tarik
  dana hanya bisa dicapai dari kartu dashboard / layar saldo.
- Bottom nav admin 4 tab: Dashboard, Pengajuan, Pindai, Riwayat. Manajemen jenis
  sampah hanya dari kartu dashboard (`context.push('/admin/trash-types')`).
- `admin_submissions_screen.dart` sudah punya sub-tab `Setoran` dan `Penarikan`
  dengan setujui/tolak.
- `admin_history_screen.dart` sudah membuka `/transaction/:id`, tetapi
  `transaction_detail_screen.dart` belum menampilkan audit, nama pengaju, atau
  nama admin penyetuju.
- Belum ada layar detail penarikan.
- `trash_types` sudah bisa ditambah/diubah/diaktifkan/dihapus dari
  `trash_type_management_screen.dart`; hapus memakai `DELETE` keras dan gagal
  bila sudah dipakai transaksi (FK `RESTRICT`).
- Layar setor hanya membaca `trash_types` dengan `is_active = true`, jadi
  penonaktifan otomatis menyembunyikan jenis dari mahasiswa.
- `Lupa kata sandi?` masih stub (`login_screen.dart:62`).

---

## PR-A — Profil mahasiswa + nomor WA saat registrasi

### Migration `20261029000000_profil_lengkap.sql`

1. `profiles.phone text` (null diizinkan) + constraint format
   `^[0-9+][0-9 -]{7,19}$`; `profiles.avatar_path text`.
2. `handle_new_user` diperbarui: baca `raw_user_meta_data->>'phone'`, simpan ke
   `profiles.phone` bila formatnya lolos; abaikan nilai tidak valid (registrasi
   tetap jalan, pengguna melengkapi di profil).
3. Bucket Storage `avatars` (private, 2 MB, `image/png|jpeg|webp`). Policy
   `select|insert|update|delete` hanya folder `(storage.foldername(name))[1] = auth.uid()::text`.
4. RPC `ubah_profil_sendiri(p_full_name text, p_nim text, p_phone text) returns jsonb`
   - security definer, `authenticated` saja.
   - Validasi: nama 2–80, NIM 3–20 alfanumerik, phone 8–20 digit.
   - NIM unik → `raise exception 'NIM sudah dipakai akun lain.'`.
   - `set_config('sibas.ubah_profil','on', true)` lalu update.
5. `guard_profile_update`: izinkan `full_name`, `nim`, `phone`, `avatar_path`
   hanya saat setting `sibas.ubah_profil` aktif; `avatar_path` yang diubah di
   luar RPC wajib `null` atau berawalan `auth.uid() || '/'`. `role`, `balance`,
   `total_weight`, `id`, `created_at`, `deleted_at` tetap terkunci.

### Dart

| File | Perubahan |
|---|---|
| `auth_repository.dart` | `signUp(..., String? phone)` kirim metadata `phone`; `ubahProfil(nama, nim, phone)`; `unggahFotoProfil(XFile)` (upload `avatars/<uid>/foto-<ts>.<ext>`, update `avatar_path`, hapus objek lama); `hapusFotoProfil()`; `ubahSandiDenganSandiLama(lama, baru)` |
| `user_model.dart` | `phone`, `avatarPath` (parse/tulis JSON) |
| `auth_provider.dart` | `CurrentUserNotifier` memperbarui state setelah ubah profil / foto tanpa reload penuh |
| `register_screen.dart` | field `Nomor WhatsApp` (keyboard telepon, validasi, opsional/ wajib? — lihat catatan) + diteruskan ke `signUp` |
| `validasi_profil.dart` (baru) | fungsi murni: nama, NIM, telepon (dipakai register & edit profil, mudah diuji) |
| `edit_profile_screen.dart` (baru) | form nama/NIM/WA; email read-only + tombol `Ubah Email`; avatar 96 px (foto / inisial), ketuk → Kamera / Galeri / Hapus |
| `profile_screen.dart` | `Ubah Nama` → `Edit Profil`; dialog sandi menambah `Sandi saat ini` dan memakai `ubahSandiDenganSandiLama` |

Catatan: nomor WA di registrasi saya usulkan **wajib** (dengan validasi) karena
dipakai admin menghubungi mahasiswa; bila Anda mau opsional, cukup ubah satu
validator.

### Uji

- `test/validasi_profil_test.dart`: nama kosong/panjang, NIM non-alfanumerik,
  telepon `+62`, spasi, huruf.

### Risiko

- Re-auth `signInWithPassword` untuk verifikasi sandi lama memicu event auth dan
  bisa menaikkan `sessionEpochProvider` (cache dibuang, tidak logout). Diuji
  manual; bila mengganggu, ganti ke jalur email konfirmasi ubah sandi.
- `avatar_path` salah validasi = foto orang lain bisa ditunjuk; policy storage +
  trigger menutup ini, harus diuji dengan dua akun.

---

## PR-B — Navigasi, detail transaksi admin, audit penarikan

### Navigasi mahasiswa

- Rute baru `/tarik` (layar Tarik Dana: nominal, saldo tersedia, riwayat
  penarikan) memakai `withdraw_sheet`/`withdrawal_provider` yang sudah ada.
- Bottom nav mahasiswa menjadi 5 tab: **Beranda, Setor, Tarik, Riwayat, Profil**
  (`app_bottom_nav.dart` + `_NavScaffold`). Bila 5 tab terlalu sempit di layar
  360 px, alternatifnya tetap 4 tab dengan `Setor | Tarik` sebagai
  `SegmentedButton` di atas layar setor — keputusan visual diserahkan ke
  designer, fungsinya sama.
- `/saldo` tetap ada dan mendapat tombol `Tarik Dana` → `/tarik`.
- Tambahkan `/tarik` ke daftar rute mahasiswa di guard router.

### Navigasi admin

- Bottom nav admin menjadi 5 tab: **Dashboard, Pengajuan, Pindai, Riwayat,
  Kelola** (Kelola = manajemen jenis sampah, rute `/admin/trash-types` sekarang
  ikut `_NavScaffold`).
- Dashboard: kartu ringkasan tetap, tetapi item terbaru bisa diketuk → detail
  transaksi/penarikan (`/transaction/:id`, `/withdrawal/:id`).
- `Riwayat` admin: ketuk baris penarikan → `/withdrawal/:id`.

### Detail transaksi (admin & mahasiswa)

- `transaction_detail_screen.dart`: tambah bagian **Pengaju** (nama + NIM) dan
  **Riwayat Proses** dari `transaction_audits` + nama aktor (`profiles.full_name`),
  plus `Disetujui/Ditolak oleh` dari `verified_by` + waktu. Tanpa UUID mentah.
- RPC `detail_transaksi(p_id uuid)` (security definer) mengembalikan transaksi +
  profil pengaju + profil penyetuju + daftar audit bernama, agar satu request
  dan tidak bergantung pada RLS join dari klien. Akses: admin atau pemilik.

### Detail penarikan (baru)

- RPC `detail_penarikan(p_id uuid)` dengan bentuk serupa.
- Layar `withdrawal_detail_screen.dart` untuk admin dan mahasiswa: nominal,
  status, pengaju, penyetuju, alasan penolakan, audit trail, dan (bila PENDING)
  tombol setujui/tolak untuk admin + QR token.

### Migration `20261031000000_audit_penarikan.sql`

1. Tabel `withdrawal_audits` (`withdrawal_id` cascade, `actor_id`, `from_status`,
   `to_status`, `note`, `created_at`); RLS select hanya admin, tulis lewat RPC.
2. `create_withdrawal` mencatat audit `null → PENDING`.
3. `approve_withdrawal` / `reject_withdrawal` mencatat audit
   `PENDING → APPROVED/REJECTED` dengan `actor_id = auth.uid()`.
4. RPC baca `detail_transaksi` dan `detail_penarikan`.

### Kriteria selesai

- Setiap approve/reject penarikan punya baris audit dengan admin yang benar.
- Detail transaksi & penarikan menampilkan nama orang, bukan UUID.
- Semua fitur baru punya jalan masuk dari navigasi, bukan hanya dashboard.

---

## PR-C — Jenis sampah: foto, kurangi, hapus aman

### Migration `20261030000000_jenis_sampah_foto.sql`

1. `trash_types.image_path text`.
2. Bucket `trash-type-images` (public read, 2 MB, mime gambar); policy tulis
   `public.is_admin()`.
3. RPC `hapus_jenis_sampah(p_id uuid) returns jsonb`
   - Terpakai transaksi → `is_active = false`, kembalikan `{"dihapus": false}`.
   - Tidak terpakai → `delete`, kembalikan `{"dihapus": true}`.
4. Tidak mengubah RPC transaksi: `price_per_kg_snapshot` sudah menyimpan harga
   saat setoran, jadi perubahan harga tidak mengubah riwayat.

### Dart

- `trash_type_repository.dart`: `hapusAman`, `unggahFoto`, `hapusFoto`.
- `trash_type_management_screen.dart`: thumbnail 40 px (foto/ikon), aksi
  unggah/ganti/hapus foto, tombol hapus memakai RPC `hapusAman` + dialog
  konsekuensi ("dinonaktifkan karena sudah dipakai").
- `setor_screen.dart`: tampilkan foto bila ada, fallback ikon Material yang sudah
  dipetakan dari nama.
- Admin bisa menambah, mengubah nama/unit/harga/deskripsi, menonaktifkan
  ("kurangi"), dan menghapus jenis yang belum terpakai. Mahasiswa hanya melihat
  yang aktif.

### Kriteria selesai

- Harga baru langsung dipakai setoran berikutnya; riwayat lama tetap memakai
  harga snapshot.
- Menghapus jenis terpakai tidak menghasilkan error merah.

---

## PR-D — QR tarik dana (jalur tambahan)

### Migration `20261032000000_tarik_dana_qr.sql`

1. `withdrawals.qr_token text not null default encode(gen_random_bytes(12),'hex')`
   + unique index; backfill baris lama.
2. RPC `tarik_by_qr(p_token text) returns jsonb` (admin, PENDING): pratinjau
   `{id, amount, mahasiswa{full_name,nim}}`, tanpa perubahan data.
3. Persetujuan tetap lewat `approve_withdrawal` (memotong saldo + audit).

### Dart

- `/tarik`: setelah pengajuan dibuat, tampilkan kartu QR payload
  `sibas-tarik:<qr_token>` + tombol perbesar; status PENDING menampilkan QR.
- `admin_scan_screen.dart`: pemilih mode `Setoran | Penarikan`; penarikan →
  `tarik_by_qr` → sheet konfirmasi (nama, NIM, nominal, saldo) → setujui.
  Web tanpa kamera: input token manual untuk kedua mode.
- Daftar pengajuan tetap bisa menyetujui tanpa QR (opsi lama dipertahankan).
- Audit mencatat admin yang memindai.

### Kriteria selesai

- Scan token memotong saldo tepat sekali; percobaan kedua ditolak.
- Token salah → pesan jelas, tanpa perubahan data.

---

## PR-E — Lupa sandi & set sandi baru

- `AuthRepository.kirimResetSandi(email)` → `resetPasswordForEmail` dengan
  `redirectTo` per platform (`sibas://reset-password` di Android,
  `https://sibas.vercel.app/#/reset-password` di web).
- Rute publik `/reset-password` (boleh diakses saat belum login; tambahkan ke
  pengecualian redirect) + layar sandi baru & konfirmasi.
- `login_screen.dart`: tombol lupa sandi mengirim email, pesan netral
  (`Bila email terdaftar, tautan atur ulang sudah dikirim.`).
- Android: intent filter `sibas://reset-password` di `AndroidManifest.xml`.
- Redirect URL Supabase diatur manual di dashboard (bukan bagian kode).
- Tanpa perubahan schema.

---

## Ditunda

- Keystore & signing rilis (APK masih debug-signed; update di atas versi lama akan
  ditolak sampai secret diisi).
- `ios/` dan pemasangan lewat Xcode (profil 7 hari).
- Play Store internal testing.

## Pertanyaan terbuka

- Nomor WA wajib atau opsional saat registrasi?
- Email resmi, lokasi unit, jam layanan admin — kini diisi admin lewat
  Pengaturan Aplikasi (`app_settings`), bukan konstanta.
- 5 tab bottom nav disetujui, atau Setor/Tarik digabung satu layar?
