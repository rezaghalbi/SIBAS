import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// Status koneksi kasar untuk banner offline (tanpa dependency baru).
final ValueNotifier<bool> offlineNotifier = ValueNotifier<bool>(false);

/// SIBAS wajib online: tidak ada mode baca dari cache.
const String pesanWajibOnline =
    'Maaf, Anda sedang offline. SIBAS memerlukan koneksi internet untuk '
    'dibuka. Sambungkan jaringan lalu coba lagi.';

/// Kegagalan yang terasa seperti masalah jaringan bagi pengguna.
class JaringanException implements Exception {
  final String pesan;
  const JaringanException(this.pesan);

  @override
  String toString() => pesan;
}

/// Sesi tidak valid lagi (401 / session_not_found). UI harus mengarahkan
/// pengguna untuk masuk ulang.
class SesiBerakhirException implements Exception {
  const SesiBerakhirException();

  @override
  String toString() => 'Sesi Anda berakhir. Silakan masuk lagi.';
}

/// Membungkus satu panggilan jaringan: beri batas waktu supaya spinner tidak
/// menggantung selamanya, tandai offline saat gagal, dan bereskan sesi 401.
///
/// Catatan: tidak memakai `dart:io` (SocketException) karena app juga jalan di web.
Future<T> guardRequest<T>(
  Future<T> Function() run, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  try {
    final hasil = await run().timeout(timeout);
    offlineNotifier.value = false;
    return hasil;
  } on TimeoutException {
    offlineNotifier.value = true;
    throw const JaringanException(
      'Maaf, koneksi terlalu lama. Sambungkan internet lalu coba lagi.',
    );
  } catch (error) {
    if (_sesiBerakhir(error)) {
      _keluarSesiDiam();
      throw const SesiBerakhirException();
    }
    if (_gangguanJaringan(error)) {
      offlineNotifier.value = true;
      throw const JaringanException(pesanWajibOnline);
    }
    // Jangan telan error domain (StateError, AuthException, PostgrestException).
    rethrow;
  }
}

/// Pesan siap tampil untuk UI. Tidak pernah memakai `toString()` mentah.
String pesanKesalahan(Object error) {
  if (error is SesiBerakhirException) {
    return 'Sesi Anda berakhir. Silakan masuk lagi.';
  }
  if (error is JaringanException) return error.pesan;
  // Permintaan lain yang gagal saat perangkat offline juga memakai pesan ini.
  if (offlineNotifier.value) return pesanWajibOnline;

  final pesan = switch (error) {
    AuthException(:final message) => message,
    PostgrestException(:final message) => message,
    _ => null,
  };
  // Pesan server berbahasa Indonesia sudah ramah pengguna; teruskan apa adanya.
  if (pesan != null && _berbahasaIndonesia(pesan)) return pesan;

  return 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
}

bool _sesiBerakhir(Object error) => switch (error) {
      AuthException(:final statusCode, :final code) =>
        statusCode == '401' || code == 'session_not_found',
      PostgrestException(:final code) => code == 'PGRST301' || code == '401',
      _ => false,
    };

bool _gangguanJaringan(Object error) {
  final pesan = switch (error) {
    AuthException(:final message) => message,
    PostgrestException(:final message) => message,
    _ => null,
  };
  if (pesan == null) return false;

  final p = pesan.toLowerCase();
  return p.contains('failed to fetch') ||
      p.contains('clientexception') ||
      p.contains('socketexception') ||
      p.contains('network');
}

bool _berbahasaIndonesia(String pesan) {
  final p = pesan.toLowerCase();
  const kata = ['tidak', 'gagal', 'sudah', 'saldo', 'wajib', 'hanya', 'belum'];
  return kata.any(p.contains);
}

/// signOut fire-and-forget: kegagalan diabaikan, sesi lokal tetap dibersihkan.
void _keluarSesiDiam() {
  try {
    unawaited(supabase.auth.signOut().catchError((Object _) {}));
  } catch (_) {
    // Klien belum siap; tidak ada yang bisa dilakukan.
  }
}
