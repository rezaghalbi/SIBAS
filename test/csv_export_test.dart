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
      'Total,Status,Alasan Ditolak',
    );
    expect(header.split(',').length, 10);
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
    expect(baris.endsWith('APPROVED,'), isTrue);
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
      'ID,Tanggal,Mahasiswa,NIM,Jumlah,Status,Alasan Ditolak',
    );
    expect(lines.first.split(',').length, 7);
    expect(
      lines[1],
      '12345678,2026-01-02 03:04,Ani,20230002,150000,PENDING,',
    );
  });
}
