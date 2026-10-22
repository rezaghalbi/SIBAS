import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const fallback = 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';

  group('authErrorMessage', () {
    test('email_not_confirmed memberi arahan verifikasi', () {
      final pesan = authErrorMessage(
        const AuthException('x', code: 'email_not_confirmed'),
      );
      expect(pesan, contains('Email belum diverifikasi'));
    });

    test('invalid_credentials menyebut kesalahan kredensial', () {
      final pesan = authErrorMessage(
        const AuthException('x', code: 'invalid_credentials'),
      );
      expect(pesan, contains('salah'));
    });

    test('nim_duplicate memberi pesan NIM terdaftar', () {
      final pesan = authErrorMessage(
        const AuthException('x', code: 'nim_duplicate'),
      );
      expect(pesan, contains('NIM sudah terdaftar'));
    });

    test('kode tak dikenal meneruskan message server', () {
      final pesan = authErrorMessage(
        const AuthException('Server sedang sibuk', code: 'kode_asing'),
      );
      expect(pesan, 'Server sedang sibuk');
    });

    test('kode tak dikenal tanpa message memakai fallback', () {
      final pesan = authErrorMessage(const AuthException('', code: 'kode_asing'));
      expect(pesan, fallback);
    });

    test('error non-AuthException tidak membocorkan toString mentah', () {
      final pesan = authErrorMessage(Exception('boom'));
      expect(pesan, fallback);
      expect(pesan, isNot(contains('boom')));
    });
  });

  group('isEmailNotConfirmed', () {
    test('true hanya untuk email_not_confirmed', () {
      expect(
        isEmailNotConfirmed(
          const AuthException('x', code: 'email_not_confirmed'),
        ),
        isTrue,
      );
      expect(
        isEmailNotConfirmed(const AuthException('x', code: 'invalid_credentials')),
        isFalse,
      );
      expect(isEmailNotConfirmed(Exception('boom')), isFalse);
    });
  });
}
