import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sibas/core/network/api_guard.dart';

void main() {
  group('pesanKesalahan', () {
    test('saat offline semua kegagalan memakai pesan wajib online', () {
      offlineNotifier.value = true;
      addTearDown(() => offlineNotifier.value = false);
      expect(
        pesanKesalahan(const JaringanException('apa saja')),
        'apa saja',
      );
      expect(
        pesanKesalahan(PostgrestException(message: 'gagal', code: '500')),
        pesanWajibOnline,
      );
    });

    test('meneruskan pesan jaringan apa adanya', () {
      expect(
        pesanKesalahan(
          const JaringanException('Koneksi terlalu lama. Periksa jaringan.'),
        ),
        'Koneksi terlalu lama. Periksa jaringan.',
      );
    });

    test('sesi berakhir punya pesan khusus', () {
      expect(
        pesanKesalahan(const SesiBerakhirException()),
        'Sesi Anda berakhir. Silakan masuk lagi.',
      );
    });

    test('pesan server berbahasa Indonesia diteruskan', () {
      expect(
        pesanKesalahan(AuthException('Email belum diverifikasi.')),
        'Email belum diverifikasi.',
      );
    });

    test('pesan teknis diganti pesan generik', () {
      final pesan = pesanKesalahan(AuthException('Invalid login credentials'));
      expect(pesan, 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.');
      expect(pesan.contains('credentials'), isFalse);
    });

    test('exception tak dikenal tidak membocorkan isi', () {
      final pesan = pesanKesalahan(Exception('boom'));
      expect(pesan, 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.');
      expect(pesan.contains('boom'), isFalse);
    });
  });

  group('guardRequest', () {
    test('mengembalikan hasil dan membersihkan status offline', () async {
      offlineNotifier.value = true;

      final hasil = await guardRequest(() async => 42);

      expect(hasil, 42);
      expect(offlineNotifier.value, isFalse);
    });

    test('berhenti dengan JaringanException saat melewati batas waktu', () async {
      await expectLater(
        guardRequest(
          () => Future<int>.delayed(
            const Duration(milliseconds: 200),
            () => 1,
          ),
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<JaringanException>()),
      );
      expect(offlineNotifier.value, isTrue);
      offlineNotifier.value = false;
    });

    test('error domain diteruskan, bukan ditelan', () async {
      await expectLater(
        guardRequest(() async => throw StateError('bentuk respons tak dikenal')),
        throwsA(isA<StateError>()),
      );
    });
  });
}
