# Analisa PRD `APP FITUR.docx` vs Kode SIBAS

Sumber PRD: `reference/APP FITUR.docx`
Tanggal analisa: berdasarkan commit terakhir sebelum push
Metode: pembacaan `lib/`, `web/`, `.github/`, `pubspec.yaml`

---

## 1. Ringkasan

Kode sudah mengikuti ~70% PRD. Arsitektur, alur transaksi utama, QR, autentikasi, dan PWA dasar sesuai.
Yang **belum** sesuai: mock data palsu di jalur error, tidak ada validasi expiry di server, tidak ada tabel audit, tidak ada test, tidak ada CRUD master data, dan RLS/RPC Supabase **tidak ada di repo** sehingga tidak bisa diaudit.

**Aturan kerja:** dokumen ini = daftar keinginan user. Setiap item yang ditandai `[ ]` belum dikerjakan. Jangan klaim selesai tanpa bukti baris kode / test.

---

## 2. Sudah sesuai PRD

| Butir PRD | Status | Bukti |
|---|---|---|
| §10 Teknologi sesuai proyek | OK | Flutter + Supabase, bukan HTML/JS karena proyek sudah Flutter |
| Clean Architecture feature-first | OK | `lib/features/{auth,dashboard,deposit,history,verification}/{data,domain,presentation}` |
| State management Riverpod | OK | `Provider`, `FutureProvider.family`, `ConsumerWidget` |
| Backend terpusat (§14D) | OK | `lib/core/network/supabase_client.dart`, semua repo pakai `_client` |
| 4 status konsisten (§5) | OK | `lib/core/utils/status_helper.dart` → Menunggu Verifikasi / Disetujui / Ditolak / Kedaluwarsa |
| QR otomatis oleh sistem, bukan admin (§4 Tahap 2) | OK | `deposit_repository.dart` insert lalu set `qr_expires_at = now + 2h` |
| QR unik per transaksi | OK | QR berisi ID transaksi; rute `/qr/:id` |
| QR expiry 2 jam | OK | `Duration(hours: 2)` di `deposit_repository.dart` |
| Scan kamera + fallback galeri + input manual UUID (§14E) | OK | `mobile_scanner` + `image_picker` + `_uuidInputController` di `admin_scan_screen.dart` |
| Guard role admin vs mahasiswa | OK | `lib/core/router/app_router.dart` redirect blok 3 & 4 |
| Approve/reject via RPC atomik (aturan arsitektur) | OK | `rpc('approve_transaction')`, `rpc('reject_transaction')` |
| Approve **tidak** mengubah berat diam-diam (§4 Tahap 3) | OK | parameter `verifiedWeightKg` nullable, default null = berat tak disentuh |
| Total berat & saldo hanya dari APPROVED (§6) | OK | `getAdminMetrics` filter `status == 'APPROVED'` |
| Riwayat mahasiswa hanya milik sendiri (§8) | OK | `getStudentTransactions(userId)` + `eq('mahasiswa_id')` |
| Dashboard admin: pending/approved/rejected/total berat (§7) | OK | `AdminMetricsModel` |
| Login/logout, dashboard, setor, riwayat | OK | rute `/login`, `/register`, `/dashboard`, `/setor`, `/history` |
| PWA manifest + theme color (§14C) | Sebagian | `web/manifest.json`, `web/index.html` (ikon bermasalah — lihat §4) |
| HTTPS produksi (§14F) | OK | Vercel default TLS |
| CI build APK + deploy web | OK | `.github/workflows/build-apk.yml` |

---

## 3. Yang belum sesuai / harus diperbaiki

### Kritis — melanggar PRD

- [ ] **Mock data palsu di dashboard admin** (§9 "jangan mengarang harga", §12 "bukan angka dibuat-buat")
  - Lokasi: `lib/features/verification/data/verification_repository.dart` → `getAdminMetrics()` blok `catch`
  - Masalah: saat query gagal, mengembalikan `totalWeightKg: 128.5, pendingCount: 4, approvedCount: 32, rejectedCount: 2` tanpa indikator error ke UI.
  - Perbaikan: lempar exception / kembalikan `AsyncError`, tampilkan state error di `admin_dashboard_screen.dart`.

- [ ] **`catch → return true` pada approve/reject** (§11 "jangan tampilkan berhasil sebelum server konfirmasi", §14F)
  - Lokasi: `approveTransaction()` dan `rejectTransaction()` blok `catch` bersarang.
  - Masalah: dua lapis `catch` sama-sama `return true`. UI menampilkan "berhasil" walau tidak ada yang tersimpan.
  - Perbaikan: hapus fallback diam-diam; semua kegagalan harus `throw` dan ditangkap di presentation sebagai SnackBar merah.

- [ ] **Fallback update langsung tanpa guard status** (§9 "terlindungi dari pemrosesan ganda")
  - Lokasi: fallback `_client.from('transactions').update({...}).eq('id', ...)` di `approveTransaction()` / `rejectTransaction()`.
  - Masalah: tidak ada `eq('status', 'PENDING')`. Transaksi yang sudah APPROVED bisa di-approve ulang → saldo bertambah dua kali.
  - Perbaikan: hapus fallback, **atau** tambah `.eq('status', 'PENDING')` + cek jumlah baris terpengaruh == 1.

- [ ] **Validasi expiry hanya di client** (§4 Ketentuan QR: "Validasi kedaluwarsa dilakukan di server")
  - Lokasi: `lib/features/deposit/presentation/screens/qr_display_screen.dart` → `_remainingTime`.
  - Masalah: `getTransactionForVerification()` dan RPC approve tidak memeriksa `qr_expires_at`. Admin bisa memproses QR kedaluwarsa.
  - Perbaikan: cek `qr_expires_at > now()` di dalam RPC `approve_transaction` (server-side). Client hanya untuk tampilan.

- [ ] **Tidak ada tabel audit transaksi** (§9 "Catat perubahan status transaksi untuk kebutuhan audit")
  - Bukti: `grep -rn 'audit' lib/` → kosong. Tidak ada tabel/trigger audit.
  - Perbaikan: tabel `transaction_audits(id, transaction_id, from_status, to_status, actor_id, reason, created_at)` + trigger di DB, atau insert eksplisit di RPC.

- [ ] **RLS & RPC Supabase tidak ada di repo**
  - Bukti: tidak ada folder `supabase/` atau `supabase/migrations/`.
  - Masalah: aturan "mahasiswa tidak dapat menyetujui sendiri" dan "mahasiswa tidak dapat melihat data orang lain" (§12) **tidak bisa diverifikasi dari kode**. Semua keamanan ada di dashboard Supabase, di luar review.
  - Perbaikan: commit `supabase/migrations/*.sql` berisi skema, RLS policy, definisi RPC `approve_transaction` / `reject_transaction`, trigger audit.

### Fitur hilang dari daftar §11

- [ ] **Layar Profil mahasiswa** — `find lib -iname '*profile*'` kosong.
- [ ] **CRUD jenis sampah & tarif** oleh admin (§3B "Mengelola ... jenis sampah", §9 "konfigurasi tarif oleh admin")
  - Bukti: `trash_types` hanya dibaca (`select`), tidak ada insert/update/delete.
- [ ] **Kelola data mahasiswa** oleh admin (§3B).

### Kualitas & pengujian

- [ ] **Tidak ada folder `test/`** (§12 daftar 11 skenario wajib). Nol test otomatis.
  - Minimum yang harus ada:
    1. Approve dua kali → saldo hanya bertambah sekali.
    2. QR kedaluwarsa → approve ditolak.
    3. Mahasiswa akses `/admin/*` → diblok.
    4. Mahasiswa A tidak bisa baca transaksi mahasiswa B.
- [ ] **Pencarian nama/NIM masih client-side** (§7 filter & pencarian)
  - Lokasi: `getAllTransactions()` filter `.where(...)` di Dart setelah `select`.
  - Masalah: boros untuk data besar; filter status + tanggal belum tentu konsisten.
  - Perbaikan: pindah ke `.ilike()` / `.gte()` / `.lte()` di query Supabase atau RPC.

### PWA (§14C)

- [ ] **Ikon manifest salah format**
  - Lokasi: `web/manifest.json` → `"sizes": "192x192 512x512"` pada satu file `favicon.png`.
  - Masalah: satu file tidak bisa dua ukuran; validasi PWA gagal.
  - Perbaikan: pisah jadi dua entri — `icons/Icon-192.png` (`192x192`) dan `icons/Icon-512.png` (`512x512`), masing-masing `"purpose": "any maskable"`.
- [ ] **Ikon masih placeholder Flutter**
  - Bukti: `web/icons/Icon-192.png` hanya 70 byte. Tidak ada `Icon-512.png`.
  - Perbaikan: ganti dengan logo SIBAS resmi (§14C "Gunakan logo SIBAS yang telah disediakan").
- [ ] **`apple-touch-icon` menunjuk favicon 70 byte** → ikon pecah di Home Screen iOS.
- [ ] **`manifest.json` tidak punya `scope`**, `start_url: "."` relatif (rapuh di subpath).
- [ ] **Service worker tanpa strategi terdokumentasi.**
  - Flutter menghasilkan `flutter_service_worker.js` otomatis. Tidak ada cache policy custom, tidak ada dokumentasi offline behavior (§14F "jangan izinkan transaksi dianggap berhasil saat offline").

---

## 4. Urutan perbaikan yang disarankan

1. [ ] Hapus mock metrik + `catch → return true`. Ganti dengan error state eksplisit.
2. [ ] Hapus fallback update langsung, atau tambah guard `eq('status','PENDING')` + verifikasi jumlah baris.
3. [ ] Pindahkan cek expiry ke RPC `approve_transaction`.
4. [ ] Commit `supabase/migrations/` — skema, RLS, RPC, tabel audit, trigger.
5. [ ] Layar Profil mahasiswa + CRUD jenis sampah/tarif + kelola mahasiswa.
6. [ ] Benahi ikon PWA (192, 512, apple-touch 180) dengan logo resmi.
7. [ ] Tambah `test/` minimal 4 skenario di §3.

---

## 5. Batasan analisa

- Tidak menjalankan `flutter analyze` / `flutter test` — Flutter SDK tidak tersedia di mesin analisa.
- Tidak mengakses project Supabase — definisi RPC & RLS tidak diverifikasi.
- Tidak menguji di perangkat fisik (Android/iOS/Windows).
- Semua klaim "sesuai" berbasis pembacaan kode, bukan eksekusi.

**Jangan tandai item selesai tanpa bukti baris kode atau test yang lulus.**