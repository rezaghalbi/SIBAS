import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/features/info/domain/models/app_settings_model.dart';
import 'package:sibas/features/info/domain/validasi_pengaturan.dart';

void main() {
  group('validasiTtlQr', () {
    test('menolak bukan angka', () {
      expect(validasiTtlQr('abc'), isNotNull);
      expect(validasiTtlQr(''), isNotNull);
    });

    test('menolak di luar 5–1440', () {
      expect(validasiTtlQr('4'), isNotNull);
      expect(validasiTtlQr('1441'), isNotNull);
    });

    test('menerima batas dan nilai umum', () {
      expect(validasiTtlQr('5'), isNull);
      expect(validasiTtlQr('120'), isNull);
      expect(validasiTtlQr('1440'), isNull);
    });
  });

  group('validasiEmailKontak', () {
    test('kosong dianggap valid', () {
      expect(validasiEmailKontak(''), isNull);
      expect(validasiEmailKontak('   '), isNull);
    });

    test('format salah ditolak', () {
      expect(validasiEmailKontak('bukan-email'), isNotNull);
      expect(validasiEmailKontak('a@b'), isNotNull);
    });

    test('format benar diterima', () {
      expect(validasiEmailKontak('admin@sibas.ac.id'), isNull);
    });
  });

  test('validasiTeksKontak membatasi 160 karakter', () {
    expect(validasiTeksKontak('a' * 160), isNull);
    expect(validasiTeksKontak('a' * 161), isNotNull);
  });

  group('AppSettingsModel.fromJson', () {
    test('membaca nilai dan memangkas spasi', () {
      final model = AppSettingsModel.fromJson({
        'qr_ttl_minutes': 90,
        'contact_email': ' admin@sibas.ac.id ',
        'contact_location': ' ',
        'contact_hours': 'Senin 08.00–12.00',
      });
      expect(model.qrTtlMinutes, 90);
      expect(model.contactEmail, 'admin@sibas.ac.id');
      expect(model.contactLocation, isNull);
      expect(model.contactHours, 'Senin 08.00–12.00');
    });

    test('memakai default 120 bila kolom tidak ada', () {
      final model = AppSettingsModel.fromJson(const {});
      expect(model.qrTtlMinutes, 120);
      expect(model.contactEmail, isNull);
    });
  });
}
