import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/features/verification/data/csv_export.dart';
import 'package:sibas/features/withdrawal/domain/models/withdrawal_model.dart';

void main() {
  test('header setoran sesuai urutan kolom', () {
    final csv = bangunCsvSetoran(const []);
    final header = csv.split('\r\n').first;
    expect(
      header,
      'Kode,Tanggal,Mahasiswa,NIM,Jenis Sampah,Berat (kg),Harga/kg,'
      'Total,Status,Alasan Ditolak,Lokasi',
    );
    expect(header.split(',').length, 11);
  });

  test('field berkoma dan berquote di-escape RFC 4180', () {
    final csv = bangunCsvSetoran([
      {
        'id': 'tx-1',
        'tx_code': 'TX,001',
        'created_at': DateTime(2026, 1, 2, 3, 4),
        'profiles': {'full_name': 'Budi "BB", S.Pd', 'nim': '20230001'},
        'trash_types': {'name': 'Plastik PET', 'price_per_kg': 3500},
        'weight': 2.5,
        'final_amount': 8750,
        'status': 'APPROVED',
      },
    ]);

    final baris = csv.split('\r\n')[1];
    expect(baris, contains('"TX,001"'));
    expect(baris, contains('"Budi ""BB"", S.Pd"'));
    expect(baris, contains(',2.50,3500,8750,APPROVED,'));
    expect(baris.endsWith('APPROVED,,'), isTrue);
  });

  test('field berawalan formula diberi kutip tunggal', () {
    final csv = bangunCsvSetoran([
      {
        'id': 'tx-3',
        'tx_code': 'TX-003',
        'created_at': DateTime(2026, 1, 2, 3, 4),
        'profiles': {'full_name': '=2+2', 'nim': '20230003'},
        'trash_types': {'name': 'Kertas', 'price_per_kg': 2000},
        'weight': 1.0,
        'final_amount': 2000,
        'status': 'APPROVED',
        'rejection_reason': '@SUM(A1)',
      },
    ]);

    final baris = csv.split('\r\n')[1];
    expect(baris, contains("'=2+2"));
    expect(baris, contains("'@SUM(A1)"));
  });

  test('menyertakan nama lokasi di kolom terakhir', () {
    final csv = bangunCsvSetoran([
      {
        'id': 'tx-2',
        'tx_code': 'TX-002',
        'created_at': DateTime(2026, 1, 2, 3, 4),
        'profiles': {'full_name': 'Budi', 'nim': '20230001'},
        'trash_types': {'name': 'Kertas', 'price_per_kg': 2000},
        'weight': 1.0,
        'final_amount': 2000,
        'status': 'APPROVED',
        'location': {'name': 'Bank Sampah Poltekkes'},
      },
    ]);

    final baris = csv.split('\r\n')[1];
    expect(baris.endsWith('APPROVED,,Bank Sampah Poltekkes'), isTrue);
  });

  test('header dan isi rekap penarikan', () {
    final csv = bangunCsvPenarikan([
      WithdrawalModel(
        id: '12345678-abcd-4bcd-9abc-000000000000',
        mahasiswaId: 'mhs-1',
        amount: 150000,
        status: 'PENDING',
        createdAt: DateTime(2026, 1, 2, 3, 4),
        studentName: 'Ani',
        studentNim: '20230002',
      ),
    ]);

    final lines = csv.split('\r\n');
    expect(
      lines.first,
      'ID,Tanggal,Mahasiswa,NIM,Jumlah,Status,Alasan Ditolak,Lokasi',
    );
    expect(lines.first.split(',').length, 8);
    expect(
      lines[1],
      '12345678,2026-01-02 03:04,Ani,20230002,150000,PENDING,,',
    );
  });
}
