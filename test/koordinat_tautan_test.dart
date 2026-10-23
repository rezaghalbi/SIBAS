import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/features/bank_location/domain/koordinat_tautan.dart';

void main() {
  group('koordinatDariTautan', () {
    test('membaca bentuk @lat,lng pada tautan peta', () {
      final hasil = koordinatDariTautan(
        'https://www.google.com/maps/@-7.797068,110.370529,17z',
      );
      expect(hasil?.latitude, '-7.797068');
      expect(hasil?.longitude, '110.370529');
    });

    test('membaca parameter q dan ll', () {
      expect(
        koordinatDariTautan('https://maps.google.com/?q=-7.8,110.36')?.latitude,
        '-7.800000',
      );
      expect(
        koordinatDariTautan('https://maps.google.com/?ll=-7.81,110.35')
            ?.longitude,
        '110.350000',
      );
    });

    test('membaca teks polos dengan spasi', () {
      final hasil = koordinatDariTautan(' -7.797068 , 110.370529 ');
      expect(hasil?.latitude, '-7.797068');
      expect(hasil?.longitude, '110.370529');
    });

    test('menolak tautan tanpa koordinat', () {
      expect(koordinatDariTautan('https://maps.google.com/'), isNull);
      expect(koordinatDariTautan(''), isNull);
      expect(koordinatDariTautan(null), isNull);
    });

    test('menolak koordinat di luar rentang', () {
      expect(koordinatDariTautan('95.000000,110.000000'), isNull);
      expect(koordinatDariTautan('-7.000000,190.000000'), isNull);
    });
  });
}
