import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/features/students/domain/models/student_model.dart';
import 'package:sibas/features/students/domain/student_filter.dart';

StudentModel _mhs({
  String nama = 'Budi',
  String? nim,
  String email = 'budi@sibas.ac.id',
  String? phone,
  DateTime? deletedAt,
}) {
  return StudentModel(
    id: nama,
    fullName: nama,
    email: email,
    nim: nim,
    phone: phone,
    deletedAt: deletedAt,
  );
}

void main() {
  final data = [
    _mhs(nama: 'Budi Santoso', nim: '071332325041', phone: '081234567890'),
    _mhs(nama: 'Siti Aminah', nim: '071332325042', email: 'siti@sibas.ac.id'),
    _mhs(
      nama: 'Akun Lama',
      email: 'lama@sibas.ac.id',
      deletedAt: DateTime(2026, 1, 1),
    ),
  ];

  test('query kosong mengembalikan semua', () {
    expect(saringMahasiswa(data, '  ').length, 3);
  });

  test('mencocokkan nama tanpa peduli kapital', () {
    expect(saringMahasiswa(data, 'budi').single.fullName, 'Budi Santoso');
  });

  test('mencocokkan NIM, email, dan nomor WA', () {
    expect(saringMahasiswa(data, '325042').single.fullName, 'Siti Aminah');
    expect(saringMahasiswa(data, 'siti@').single.fullName, 'Siti Aminah');
    expect(saringMahasiswa(data, '812345').single.fullName, 'Budi Santoso');
  });

  test('akun terhapus tetap bisa ditemukan dan ditandai', () {
    final hasil = saringMahasiswa(data, 'akun lama').single;
    expect(hasil.terhapus, isTrue);
  });

  test('tidak ada hasil bila tidak cocok', () {
    expect(saringMahasiswa(data, 'zzz'), isEmpty);
  });

  test('StudentModel.fromJson mengisi fallback nama', () {
    final model = StudentModel.fromJson({
      'id': 'x',
      'full_name': '  ',
      'email': 'x@sibas.ac.id',
      'balance': 1500,
    });
    expect(model.fullName, 'Pengguna SIBAS');
    expect(model.balance, 1500);
    expect(model.nim, isNull);
  });
}
