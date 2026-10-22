import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/app_info.dart';
import 'api_guard.dart';
import 'supabase_client.dart';

bool _sedangLapor = false;

/// Kirim error tak tertangkap ke tabel client_error_logs lewat RPC.
/// Pelaporan tidak boleh memicu error baru atau berulang.
Future<void> laporkanKesalahan(
  Object error,
  StackTrace? stack, {
  String? konteks,
}) async {
  if (_sedangLapor) return;
  if (_diabaikan(error)) return;

  _sedangLapor = true;
  try {
    final tipe = error.runtimeType.toString();
    final isi = error.toString();
    final ringkas = isi.length > 300 ? '${isi.substring(0, 300)}...' : isi;
    final pesan = [
      if (konteks != null) konteks,
      tipe,
      ringkas,
    ].join(' | ');

    final params = <String, dynamic>{
      'p_pesan': pesan.length > 500 ? pesan.substring(0, 500) : pesan,
      'p_detail': _potong(stack?.toString(), 2000),
      'p_platform': kIsWeb ? 'web' : 'android',
      'p_versi': appVersion,
    };
    // Bukan guardRequest: pelaporan error tidak boleh ikut memicu signOut
    // atau menyalakan banner offline.
    await supabase
        .rpc('log_client_error', params: params)
        .timeout(const Duration(seconds: 10));
  } catch (_) {
    // Pelaporan bersifat best-effort; error di sini ditelan.
  } finally {
    _sedangLapor = false;
  }
}

/// Jaringan/sesi putus bukan bug aplikasi, jadi tidak perlu dicatat.
bool _diabaikan(Object error) {
  if (error is SesiBerakhirException || error is JaringanException) {
    return true;
  }
  return error.toString().toLowerCase().contains('failed to fetch');
}

String? _potong(String? teks, int maks) {
  if (teks == null) return null;
  return teks.length > maks ? teks.substring(0, maks) : teks;
}
