import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan pilihan tampilan (terang, gelap, atau ikut sistem).
///
/// Nilai disimpan sebagai string di `shared_preferences` agar sederhana dan
/// tetap terbaca saat versi berikutnya menambah opsi.
const _kunciMode = 'sibas.theme_mode';

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Nilai awal mengikuti sistem; preferensi tersimpan dibaca lewat
    // [muat] agar build tetap sinkron.
    Future.microtask(muat);
    return ThemeMode.system;
  }

  /// Membaca preferensi tersimpan, sekali saat aplikasi mulai.
  Future<void> muat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tersimpan = prefs.getString(_kunciMode);
      final mode = _dariTeks(tersimpan);
      if (mode != null && mode != state) {
        state = mode;
      }
    } catch (_) {
      // Preferensi gagal dibaca bukan alasan menggagalkan aplikasi.
    }
  }

  Future<void> ubah(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kunciMode, mode.name);
    } catch (_) {
      // Tetap pakai pilihan di sesi ini walau penyimpanan gagal.
    }
  }

  static ThemeMode? _dariTeks(String? teks) {
    switch (teks) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
