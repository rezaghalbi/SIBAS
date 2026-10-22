# Rencana Lanjutan SIBAS

Dokumen kerja. Tidak ada kode di sini; setiap fase dikerjakan sebagai PR terpisah
dengan verifikasi CI (`Analyze & Test` + `Build APK & Web`).

## Keputusan yang sudah diambil

- Tarik dana: **QR lokal** (mahasiswa menampilkan QR token, admin memindai),
  bukan payment gateway. Uang diserahkan di luar aplikasi.
- Logo jenis sampah: **ikon Material** sebagai default, foto unggahan admin
  opsional (Supabase Storage). Tanpa plugin ikon.
- Urutan: rencana detail → Fase 1 (profil) → Fase 2 (admin, audit, tarik dana,
  reset sandi) → Fase 3 (distribusi Android/iOS).

## Kondisi awal yang relevan

- `profiles`: `id, email, full_name, nim, role, balance, total_weight, created_at, deleted_at`.
  Belum ada `phone`, belum ada `avatar_path`.
- `guard_profile_update` menolak perubahan `nim`, `email`, `deleted_at`, dll untuk
  non-admin. Setiap fitur edit diri harus punya jalur yang sah (RPC), bukan
  membuka kolom mentah.
- `trash_types`: `name, unit, price_per_kg, description, is_active, created_at`.
  Layar admin sudah ada (`trash_type_management_screen.dart`), hapus memakai
  `DELETE` keras; FK `transactions.trash_type_id` memakai `RESTRICT`.
- `transaction_audits`: `transaction_id, actor_id, from_status, to_status, note, created_at`.
  Tidak ada padanan untuk `withdrawals`.
- `withdrawals`: `id, mahasiswa_id, amount, status, rejection_reason, verified_by,
  verified_at, created_at`. `approve_withdrawal` memotong saldo, tidak menulis audit.
- Login: tombol `Lupa kata sandi?` masih stub (`login_screen.dart:62`).
- APK masih debug-signed (tanpa `android/key.properties`).

---

## Fase 1 — Profil mahasiswa

### Migration `20261029000000_profil_lengkap.sql`

1. Kolom baru:
   - `profiles.phone text` (null diizinkan), constraint format
     `^[0-9+][0-9 -]{7,19}$`.
   - `profiles.avatar_path text` (null diizinkan), constraint
     `avatar_path like auth.uid() || '/%'` **tidak** bisa di constraint (butuh
     `auth.uid()`), jadi validasi di trigger.
2. Bucket Storage `avatars` (private, batas 2 MB, mime `image/png|jpeg|webp`).
   Policy: `select|insert|update|delete` hanya untuk folder
   `(storage.foldername(name))[1] = auth.uid()::text`. Admin tidak butuh akses.
3. RPC `ubah_profil_sendiri(p_full_name text, p_nim text, p_phone text) returns jsonb`
   - security definer, `set search_path to 'public'`, hanya `authenticated`.
   - Validasi: nama 2–80 karakter, NIM 3–20 karakter alfanumerik, phone 8–20
     digit (simpan ternormalisasi `+62...` atau apa adanya setelah trim).
   - NIM unik: `unique_violation` → `raise exception 'NIM sudah dipakai akun lain.'`.
   - Set `set_config('sibas.ubah_profil','on', true)` lalu update 3 kolom.
4. `guard_profile_update` diperbarui: izinkan perubahan `full_name`, `nim`,
   `phone`, `avatar_path` ketika `sibas.ubah_profil` aktif; tetap tolak `role`,
   `balance`, `total_weight`, `id`, `created_at`, `deleted_at`. Tanpa setting
   tersebut, perilaku lama (admin-only) dipertahankan.
5. `avatar_path` boleh diubah lewat update biasa **hanya** bila nilainya diawali
   `auth.uid() || '/'` atau null; selain itu trigger menolak.

### Dart

| File | Perubahan |
|---|---|
| `lib/features/auth/domain/models/user_model.dart` | field `phone`, `avatarPath`; parse `fromJson`, tulis `toJson` |
| `lib/features/auth/data/auth_repository.dart` | `ubahProfil(nama, nim, phone)` → RPC; `unggahFotoProfil(XFile)` → upload `avatars/<uid>/foto-<ts>.<ext>` lalu update `avatar_path` + hapus objek lama; `hapusFotoProfil()`; `ubahSandiDenganSandiLama(lama, baru)` = `signInWithPassword` lalu `updateUser(password:)` |
| `lib/features/auth/presentation/providers/auth_provider.dart` | `CurrentUserNotifier.ubahProfil/unggahFoto/hapusFoto` yang memperbarui `state` tanpa reload penuh |
| `lib/features/profile/domain/validasi_profil.dart` (baru) | fungsi murni validasi nama/NIM/telepon — dipakai UI dan bisa diuji |
| `lib/features/profile/presentation/screens/edit_profile_screen.dart` (baru) | form nama, NIM, nomor WA; email sebagai read-only + tombol `Ubah Email`; avatar bulat 96 px (foto atau inisial), ketuk → pilihan Kamera/Galeri/Hapus |
| `lib/features/profile/presentation/screens/profile_screen.dart` | `Ubah Nama` → `Edit Profil`; dialog sandi menambah field `Sandi saat ini` dan memakai `ubahSandiDenganSandiLama` |

- Placeholder avatar: `CircleAvatar` dengan inisial nama (bukan file aset),
  konsisten dengan header profil yang sudah ada.
- Tampilan avatar di aplikasi: `createSignedUrl` umur 1 jam, cache di provider;
  jangan simpan URL publik permanen.
- `image_picker` dan `qr_flutter` sudah menjadi dependency; tidak ada dependency
  baru untuk fase ini.

### Uji

- `test/validasi_profil_test.dart`: nama kosong/terlalu panjang, NIM non-alfanumerik,
  nomor telepon dengan `+62`, spasi, dan karakter asing.

### Kriteria selesai Fase 1

- Mahasiswa dapat mengubah nama, NIM, dan nomor WA; NIM duplikat ditolak dengan
  pesan Indonesia.
- Foto profil bisa diunggah dari kamera atau galeri, bisa dihapus, dan kembali ke
  placeholder inisial.
- Ubah sandi gagal bila sandi lama salah; berhasil bila benar; tidak ada teks
  error berbahasa Inggris.
- `flutter analyze` + `flutter test` hijau di CI; build APK/Web hijau.

### Risiko

- Re-auth `signInWithPassword` memicu event auth; `sessionEpochProvider` akan
  naik bila provider mendengarkan `signedIn`. Perlu dicek agar cache tidak
  terbuang dan pengguna tidak ter-logout. Bila bermasalah, ganti pendekatan:
  verifikasi sandi lama lewat RPC `verifikasi_sandi` (security definer tidak bisa
  membaca hash auth) — alternatifnya, kirim email konfirmasi ubah sandi.
- Storage policy salah = unggahan gagal dengan galat 403; uji manual setelah
  migration diterapkan.

---

## Fase 2A — Jenis sampah: foto dan penghapusan aman

### Migration `20261030000000_jenis_sampah_foto.sql`

1. `trash_types.image_path text` (null → pakai ikon Material).
2. Bucket `trash-type-images` (public read, 2 MB, mime gambar).
   Policy tulis: `public.is_admin()`.
3. RPC `hapus_jenis_sampah(p_id uuid) returns jsonb`
   - Jika ada `transactions` yang merujuk: `update trash_types set is_active=false`
     dan kembalikan `{"dihapus": false, "alasan": "dinonaktifkan"}`.
   - Jika tidak ada: `delete` dan kembalikan `{"dihapus": true}`.
   - Alasan: FK `RESTRICT` membuat `DELETE` gagal; jangan sembunyikan galat ke
     pengguna.

### Dart

- `trash_type_repository.dart`: `hapusAman(id)` → RPC di atas; `unggahFoto(id, XFile)`
  → storage + update `image_path`; `hapusFoto(id)`.
- `trash_type_management_screen.dart`: tombol foto (unggah/ganti/hapus), tampil
  thumbnail bulat 40 px; konfirmasi hapus menyebut konsekuensi (dinonaktifkan
  bila sudah dipakai).
- `setor_screen.dart`: ikon default tetap; bila `image_path` ada, tampilkan
  `Image.network` 32–40 px bulat dengan fallback ikon saat gagal muat.

### Kriteria selesai Fase 2A

- Admin dapat mengganti foto jenis sampah; mahasiswa melihat perubahan setelah
  layar setor dimuat ulang.
- Menghapus jenis yang sudah dipakai transaksi tidak menghasilkan galat merah;
  jenis menjadi nonaktif dan hilang dari pilihan setor.

---

## Fase 2B — Audit transaksi dan penarikan

### Migration `20261031000000_audit_penarikan.sql`

1. Tabel `withdrawal_audits` (mirror `transaction_audits`):
   `id bigserial pk, withdrawal_id uuid fk cascade, actor_id uuid fk profiles,
   from_status text, to_status text, note text, created_at timestamptz`.
2. RLS: `select` hanya `public.is_admin()`; tulis hanya lewat RPC (security definer).
3. `create_withdrawal`: catat audit `null → PENDING` dengan actor = pengaju.
4. `approve_withdrawal` dan `reject_withdrawal`: catat audit `PENDING → APPROVED/REJECTED`
   dengan actor = admin yang memproses (sudah `auth.uid()`), note alasan untuk reject.
5. RPC baca `detail_penarikan(p_id uuid) returns jsonb` (admin atau pemilik):
   data penarikan + profil pengaju + `profiles` penyetuju + daftar audit dengan
   nama aktor. Tujuannya satu request, bukan tiga query dari klien.

### Dart

- `transaction_detail_screen.dart`: bagian `Riwayat Proses` — diajukan oleh,
  disetujui/ditolak oleh (nama + waktu), alasan penolakan; ambil dari
  `transaction_audits` + `profiles(verified_by)`.
- Layar baru `withdrawal_detail_screen.dart` (admin + mahasiswa): status, jumlah,
  pengaju (nama/NIM), penyetuju, audit trail.
- `admin_history_screen.dart` / `admin_submissions_screen.dart`: buka detail
  penarikan dari daftar.

### Kriteria selesai Fase 2B

- Setiap approve/reject penarikan punya baris audit dengan `actor_id` admin.
- Detail menampilkan nama admin penyetuju, bukan UUID.
- Uji: dua transaksi approve/reject di akun uji, cek baris audit muncul (SQL),
  dan UI menampilkan nama yang benar.

---

## Fase 2C — Tarik dana via QR

### Migration `20261032000000_tarik_dana_qr.sql`

1. `withdrawals.qr_token text not null default encode(gen_random_bytes(12),'hex')`
   + unique index; backfill baris lama.
2. RPC `tarik_by_qr(p_token text) returns jsonb` — hanya admin, status PENDING:
   kembalikan `{id, amount, mahasiswa: {full_name, nim}, created_at}`. Tidak
   mengubah apa pun (read-only untuk pratinjau).
3. `approve_withdrawal` tetap memotong saldo dan menulis audit (Fase 2B).

### Dart

- `withdraw_sheet.dart` / layar saldo: setelah pengajuan `PENDING`, tampilkan
  kartu QR (`QrImageView`, payload `sibas-tarik:<qr_token>`) + tombol `Perbesar`.
  Token diambil dari baris penarikan yang baru dibuat (`select` setelah insert).
- `admin_scan_screen.dart`: pemilih mode `Setoran` / `Penarikan`.
  - Setoran: alur lama (`get_transaction_by_qr`).
  - Penarikan: `sibas-tarik:<token>` → `tarik_by_qr` → sheet konfirmasi (nama,
    NIM, nominal, saldo tersedia) → `approve_withdrawal` → SnackBar sukses,
    audit tercatat, saldo mahasiswa berkurang.
  - Web: tanpa kamera (sudah ada guard `kIsWeb`), input token manual untuk kedua
    mode.
- Mahasiswa: status `PENDING` menampilkan QR + instruksi "tunjukkan ke admin".

### Kriteria selesai Fase 2C

- Scan token penarikan di Android memotong saldo tepat sekali; percobaan kedua
  ditolak `Pengajuan sudah diproses`.
- Token yang salah/tidak ada → pesan jelas, tanpa perubahan data.
- Audit mencatat admin yang memindai.

---

## Fase 2D — Lupa kata sandi

- `AuthRepository.kirimResetSandi(email)` → `resetPasswordForEmail(email,
  redirectTo: 'sibas://reset-password')`.
- Layar baru `reset_password_screen.dart`, rute publik `/reset-password`
  (`/reset-password?code=...`), berisi sandi baru + konfirmasi.
- Android: intent filter `sibas://reset-password` di `AndroidManifest.xml`.
- Web: tambahkan `https://sibas.vercel.app/#/reset-password` ke Redirect URLs
  Supabase (dashboard, manual) dan gunakan `redirectTo` sesuai platform.
- `login_screen.dart`: `_handleForgotPassword` memanggil repository, menampilkan
  banner `Tautan atur ulang dikirim ke <email>. Periksa kotak masuk.`
- Tanpa perubahan schema.

### Kriteria selesai Fase 2D

- Email reset terkirim (uji dengan akun yopmail), tautan membuka layar set sandi,
  sandi baru bisa dipakai login, sandi lama tidak.
- Email tidak dikenal tidak membocorkan status akun (pesan tetap netral).

---

## Fase 3 — Distribusi

1. Keystore + empat secret; verifikasi `Subject` sertifikat APK = kunci Anda.
2. Naikkan `version:` tiap rilis; APK release-signed bisa dipasang sebagai update.
3. Android "aplikasi tidak dikenal": tidak bisa dihilangkan untuk sideload.
   Opsi: Play Store internal testing (akun developer $25, hilang peringatan) atau
   dokumentasi sideload (aktifkan izin sekali, tetap ada peringatan).
4. iOS: commit `ios/` (bundle id `com.sibas.poltekkes.sibas`), langkah Xcode
   dengan Apple ID gratis (profil 7 hari, harus dipasang ulang mingguan).
   CI Linux tidak bisa membangun iOS; build dilakukan di MacBook.

---

## Di luar fase (usulan berikutnya)

- Realtime Supabase untuk daftar pengajuan dan saldo.
- Notifikasi tersimpan + push (FCM).
- Manajemen pengguna admin (koreksi saldo dengan audit, pencarian mahasiswa).
- Laporan bulanan + PDF; antrean offline; mode gelap; halaman privasi.
- Uji integrasi/E2E (Playwright untuk web).

## Pertanyaan terbuka

- Email resmi, lokasi unit, dan jam layanan admin (sekarang "Belum diatur").
- Apakah Play Store internal testing akan dipakai, atau cukup sideload.
