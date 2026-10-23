import 'package:flutter/material.dart';

import 'app_palette.dart';
import '../theme/sibas_colors.dart';

/// Warna yang mengikuti tema aktif untuk kode lama.
///
/// `AppPalette` adalah sumber token resmi (dipakai komponen seperti
/// `SurfaceCard`, `GlassPanel`, dan `AppTheme.darkTheme`). Layar lama masih
/// membaca konstanta, sehingga butuh satu titik baca yang nilainya berubah
/// mengikuti mode terang/gelap tanpa harus menurunkan `BuildContext`.
///
/// Nilai di sini **tidak boleh** dipakai untuk membangun `ThemeData`: tema
/// selalu memakai token eksplisit agar light dan dark bisa dibangun sekaligus.
///
/// Mode ditentukan oleh [applyBrightness] (pilihan pengguna) dan jatuh ke
/// `platformBrightness` bila belum ada pilihan.
@immutable
class SibasColors {
  SibasColors._();

  static Brightness? _manual;
  static bool _platformDark = false;

  /// Dipanggil sekali saat aplikasi mulai dan setiap mode berubah.
  static void applyMode({Brightness? manual, bool platformDark = false}) {
    _manual = manual;
    _platformDark = platformDark;
  }

  static Brightness get brightness => _manual ??
      (_platformDark ? Brightness.dark : Brightness.light);

  static AppPalette get palette =>
      brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;

  static AppStatusColors get status => AppStatusColors.of(brightness);

  // Token permukaan.
  static Color get background => palette.background;
  static Color get backgroundTint => palette.backgroundTint;
  static Color get surface => palette.surface;
  static Color get surfaceAlt => palette.surfaceAlt;
  static Color get elevated => palette.elevated;

  // Teks.
  static Color get text => palette.text;
  static Color get muted => palette.muted;
  static Color get faint => palette.faint;

  // Merek dan aksi.
  static Color get primary => palette.primary;
  static Color get onPrimary => palette.onPrimary;
  static Color get leaf => palette.leaf;
  static Color get lime => palette.lime;
  static Color get mint => palette.mint;
  static Color get mintWash => palette.mintWash;
  static Color get link => palette.link;

  // Garis dan scrim.
  static Color get border => palette.border;
  static Color get borderStrong => palette.borderStrong;
  static Color get scrim => palette.scrim;

  // Hero dan kaca.
  static Color get heroStart => palette.heroStart;
  static Color get heroMid => palette.heroMid;
  static Color get heroEnd => palette.heroEnd;
  static Color get heroInk => palette.heroInk;
  static Color get heroMuted => palette.heroMuted;
  static Color get heroGlow => palette.heroGlow;
  static Color get glassTop => palette.glassTop;
  static Color get glassBottom => palette.glassBottom;
  static Color get glassBorder => palette.glassBorder;
  static Color get glassHighlight => palette.glassHighlight;

  static LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.heroStart, palette.heroMid, palette.heroEnd],
      );
}
