# Product Requirement Document (PRD) - SIBAS

## 1. Identitas & Batasan Utama
- Nama: SIBAS (Sistem Informasi Bank Sampah - Poltekkes Kemenkes Yogyakarta).
- Dilarang menggunakan CAPTCHA.
- Dilarang mengubah nama aplikasi.
- Input berat sampah WAJIB manual (kg) oleh mahasiswa. Dilarang menggunakan sensor otomatis.

## 2. Hak Akses
- **Mahasiswa**: Login/Logout, Dashboard (Saldo, Total Berat Disetujui, Transaksi Pending), Form Setor (Pilih Jenis Sampah, Berat Manual kg), Tampilan QR Transaksi, Riwayat Setoran.
- **Admin**: Login/Logout, Dashboard (Metrics Pending/Approved/Rejected/Total Berat), Pemindai QR Kamera, Detail Verifikasi (Aksi: Setujui / Tolak + Alasan), Kelola Tarif & Jenis Sampah, Audit Trail.

## 3. Matriks Status Transaksi & Pemetaan Label UI
- **Database Status**:
  - `PENDING`: Dibuat mahasiswa, QR berlaku 2 jam di server.
  - `APPROVED`: Disetujui admin, saldo & total berat bertambah secara atomic via RPC.
  - `REJECTED`: Ditolak admin, saldo & berat tidak bertambah, alasan dicatat.
  - `EXPIRED`: Waktu pengajuan > 2 jam sebelum diproses admin.
- **Pemetaan Label Status UI Resmi (Wajib Digunakan di UI)**:
  - `PENDING` -> `'Menunggu Verifikasi'` (Badge/Warna netral/kuning/oranye)
  - `APPROVED` -> `'Disetujui'` (Badge/Warna hijau daun `#16865D`)
  - `REJECTED` -> `'Ditolak'` (Badge/Warna merah `#D32F2F`)
  - `EXPIRED` -> `'Kedaluwarsa'` (Badge/Warna abu-abu)

## 4. Keamanan & QR Rule
- QR hanya berisi `transaction_id` (UUID). Dilarang menyimpannya dalam bentuk password atau token sensitif.
- QR hanya berlaku 1 kali penggunaan.
- **Fallback Pemindaian QR Admin**: Jika izin akses kamera tidak diizinkan atau perangkat mengalami kendala kamera, sistem wajib menyediakan fallback alternatif berupa unggah file gambar/foto QR dari galeri/penyimpanan perangkat untuk diekstrak.

## 5. Fitur Dashboard Admin & Filter Data
- **Pencarian Data**: Mendukung pencarian berbasis Nama Mahasiswa atau NIM.
- **Filter Data**: Mendukung penyaringan multi-kriteria berdasarkan status transaksi (`Menunggu Verifikasi`, `Disetujui`, `Ditolak`, `Kedaluwarsa`) dan rentang tanggal transaksi.

## 6. Penanganan Dinamis Tarif Sampah (Rp/kg)
- Jika tarif Rp/kg bernilai 0 atau belum diset (misal jenis sampah belum ditentukan nilai konversinya), sistem **wajib menyembunyikan card/elemen nominal saldo (Rp)** pada UI mahasiswa maupun admin, dan mengalihkan fokus tampilan penuh ke metrik berat dalam satuan kilogram (kg).