import '../../withdrawal/domain/models/withdrawal_model.dart';

/// Pembangun CSV rekap admin. Murni Dart, tanpa I/O, agar mudah diuji.
const _pemisahBaris = '\r\n';

const _headerSetoran = 'Kode,Tanggal,Mahasiswa,NIM,Jenis Sampah,'
    'Berat (kg),Harga/kg,Total,Status,Alasan Ditolak,Lokasi';

const _headerPenarikan = 'ID,Tanggal,Mahasiswa,NIM,'
    'Jumlah,Status,Alasan Ditolak,Lokasi';

/// Rekap setoran dari baris mentah repository (sudah berisi relasi join).
String bangunCsvSetoran(List<Map<String, dynamic>> data) {
  final baris = <String>[_headerSetoran];
  for (final row in data) {
    final profil = _peta(row['profiles']);
    final jenis = _peta(row['trash_types']);
    final total = row['final_amount'] ?? row['estimated_amount'];

    baris.add(
      [
        _teks(row['tx_code']),
        _tanggal(row['created_at']),
        _teks(profil['full_name']),
        _teks(profil['nim']),
        _teks(jenis['name']),
        _desimal(row['weight'], 2),
        _desimal(jenis['price_per_kg'], 0),
        _desimal(total, 0),
        _teks(row['status']),
        _teks(row['rejection_reason']),
        // Nama lokasi dari relasi `location`; kolom terakhir agar urutan
        // kolom lama tidak bergeser.
        _lokasi(row['location']),
      ].map(_escape).join(','),
    );
  }
  return '${baris.join(_pemisahBaris)}$_pemisahBaris';
}

/// Rekap penarikan saldo mahasiswa.
String bangunCsvPenarikan(List<WithdrawalModel> data) {
  final baris = <String>[_headerPenarikan];
  for (final w in data) {
    baris.add(
      [
        // Penarikan tidak punya kode; pakai 8 karakter awal id.
        _potong(w.id),
        _tanggal(w.createdAt),
        _teks(w.studentName),
        _teks(w.studentNim),
        _desimal(w.amount, 0),
        _teks(w.status),
        _teks(w.rejectionReason),
        _lokasiDariNama(w.locationName),
      ].map(_escape).join(','),
    );
  }
  return '${baris.join(_pemisahBaris)}$_pemisahBaris';
}

Map<String, dynamic> _peta(Object? nilai) =>
    nilai is Map ? Map<String, dynamic>.from(nilai) : const <String, dynamic>{};

/// Nama lokasi dari objek relasi `location`; kosong bila tidak ada.
String _lokasi(Object? nilai) => _lokasiDariNama(_peta(nilai)['name']);

/// Trim nama lokasi agar sel kosong berisi string kosong, bukan spasi.
String _lokasiDariNama(Object? nilai) => nilai?.toString().trim() ?? '';

String _teks(Object? nilai) => nilai?.toString() ?? '';

/// Delapan karakter awal id, aman untuk id yang lebih pendek.
String _potong(String nilai) =>
    nilai.length > 8 ? nilai.substring(0, 8) : nilai;

String _desimal(Object? nilai, int digit) =>
    nilai is num ? nilai.toStringAsFixed(digit) : '';

/// Format lokal `yyyy-MM-dd HH:mm`.
String _tanggal(Object? nilai) {
  final mentah = nilai?.toString() ?? '';
  final waktu = nilai is DateTime ? nilai : DateTime.tryParse(mentah);
  if (waktu == null) return '';
  final lokal = waktu.toLocal();
  String dua(int n) => n.toString().padLeft(2, '0');
  return '${lokal.year}-${dua(lokal.month)}-${dua(lokal.day)} '
      '${dua(lokal.hour)}:${dua(lokal.minute)}';
}

/// Bungkus field yang mengandung koma, kutip, atau baris baru (RFC 4180).
///
/// Awalan `=`, `+`, `-`, `@`, tab, atau CR bisa dieksekusi sebagai formula
/// saat CSV dibuka di Excel/Sheets. Tambahkan kutip tunggal agar sel
/// diperlakukan sebagai teks (CSV injection).
String _escape(String nilai) {
  if (nilai.isEmpty) return nilai;
  final aman = '=+-@\t\r'.contains(nilai[0]) ? "'$nilai" : nilai;
  final perluKutip = aman.contains(',') ||
      aman.contains('"') ||
      aman.contains('\n') ||
      aman.contains('\r');
  if (!perluKutip) return aman;
  return '"${aman.replaceAll('"', '""')}"';
}
