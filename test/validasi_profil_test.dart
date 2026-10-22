import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/features/profile/domain/validasi_profil.dart';

void main() {
  group('validasiNama', () {
    test('kosong ditolak', () {
      expect(validasiNama('  '), isNotNull);
      expect(validasiNama(null), isNotNull);
    });

    test('kepanjangan ditolak', () {
      expect(validasiNama(List.filled(81, 'a').join()), isNotNull);
    });

    test('wajar lolos', () {
      expect(validasiNama('Budi Santoso'), isNull);
    });
  });

  group('validasiNim', () {
    test('kosong ditolak', () {
      expect(validasiNim(''), isNotNull);
    });

    test('strip ditolak', () {
      expect(validasiNim('2210-1234'), isNotNull);
    });

    test('terlalu pendek ditolak', () {
      expect(validasiNim('12'), isNotNull);
    });

    test('8 digit lolos', () {
      expect(validasiNim('22101234'), isNull);
    });

    test('huruf dan angka lolos', () {
      expect(validasiNim('A2210123'), isNull);
    });
  });

  group('validasiNomorWa', () {
    test('081234567890 lolos', () {
      expect(validasiNomorWa('081234567890'), isNull);
    });

    test('+62 dengan spasi dan strip lolos', () {
      expect(validasiNomorWa('+62 812-3456-7890'), isNull);
    });

    test('huruf ditolak', () {
      expect(validasiNomorWa('abc'), isNotNull);
    });

    test('terlalu pendek ditolak', () {
      expect(validasiNomorWa('0812345'), isNotNull);
    });

    test('kosong ditolak', () {
      expect(validasiNomorWa(null), isNotNull);
    });
  });
}
