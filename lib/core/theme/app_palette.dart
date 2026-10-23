import 'package:flutter/material.dart';

/// Token warna SIBAS Glass 2.0 untuk light dan dark.
///
/// Nilai diambil apa adanya dari `docs/DESIGN_SYSTEM_V2.md`:
/// - §2.1 untuk [AppPalette.light]
/// - §2.2 untuk [AppPalette.dark]
/// - §2.3 untuk [AppStatusColors]
///
/// `AppColors` tetap menjadi konstanta brand mentah untuk layar lama. Layar
/// baru membaca token lewat `AppPalette.of(context)`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.backgroundTint,
    required this.surface,
    required this.surfaceAlt,
    required this.elevated,
    required this.text,
    required this.muted,
    required this.faint,
    required this.primary,
    required this.onPrimary,
    required this.leaf,
    required this.lime,
    required this.mint,
    required this.mintWash,
    required this.link,
    required this.border,
    required this.borderStrong,
    required this.scrim,
    required this.heroStart,
    required this.heroMid,
    required this.heroEnd,
    required this.heroInk,
    required this.heroMuted,
    required this.heroGlow,
    required this.glassTop,
    required this.glassBottom,
    required this.glassBorder,
    required this.glassHighlight,
  });

  final Brightness brightness;

  /// Latar halaman dan tint aurora di belakang konten.
  final Color background;
  final Color backgroundTint;

  /// Permukaan solid: kartu, rail, field, dan sheet.
  final Color surface;
  final Color surfaceAlt;
  final Color elevated;

  /// Hierarki teks: utama, sekunder, dan metadata/placeholder.
  final Color text;
  final Color muted;
  final Color faint;

  /// Warna merek dan aksi.
  final Color primary;
  final Color onPrimary;
  final Color leaf;
  final Color lime;
  final Color mint;
  final Color mintWash;
  final Color link;

  /// Garis dan lapisan penutup.
  final Color border;
  final Color borderStrong;
  final Color scrim;

  /// Gradien hero dan warna teks di atasnya.
  final Color heroStart;
  final Color heroMid;
  final Color heroEnd;
  final Color heroInk;
  final Color heroMuted;
  final Color heroGlow;

  /// Kaca tone `subtle` (§7.2).
  final Color glassTop;
  final Color glassBottom;
  final Color glassBorder;
  final Color glassHighlight;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  /// Token tidak diubah per subtree; satu instance per tema.
  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    Color campur(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: campur(background, other.background),
      backgroundTint: campur(backgroundTint, other.backgroundTint),
      surface: campur(surface, other.surface),
      surfaceAlt: campur(surfaceAlt, other.surfaceAlt),
      elevated: campur(elevated, other.elevated),
      text: campur(text, other.text),
      muted: campur(muted, other.muted),
      faint: campur(faint, other.faint),
      primary: campur(primary, other.primary),
      onPrimary: campur(onPrimary, other.onPrimary),
      leaf: campur(leaf, other.leaf),
      lime: campur(lime, other.lime),
      mint: campur(mint, other.mint),
      mintWash: campur(mintWash, other.mintWash),
      link: campur(link, other.link),
      border: campur(border, other.border),
      borderStrong: campur(borderStrong, other.borderStrong),
      scrim: campur(scrim, other.scrim),
      heroStart: campur(heroStart, other.heroStart),
      heroMid: campur(heroMid, other.heroMid),
      heroEnd: campur(heroEnd, other.heroEnd),
      heroInk: campur(heroInk, other.heroInk),
      heroMuted: campur(heroMuted, other.heroMuted),
      heroGlow: campur(heroGlow, other.heroGlow),
      glassTop: campur(glassTop, other.glassTop),
      glassBottom: campur(glassBottom, other.glassBottom),
      glassBorder: campur(glassBorder, other.glassBorder),
      glassHighlight: campur(glassHighlight, other.glassHighlight),
    );
  }

  /// §2.1 Light
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF3F8F5),
    backgroundTint: Color(0xFFE8F3EC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF7FBF8),
    elevated: Color(0xFFFFFFFF),
    text: Color(0xFF12201A),
    muted: Color(0xFF5C6E65),
    faint: Color(0xFF83948B),
    primary: Color(0xFF005746),
    onPrimary: Color(0xFFFFFFFF),
    leaf: Color(0xFF16865D),
    lime: Color(0xFF9BD84A),
    mint: Color(0xFFDFF3E8),
    mintWash: Color(0xFFEAF7F0),
    link: Color(0xFF0E7350),
    border: Color.fromRGBO(15, 60, 40, 0.10),
    borderStrong: Color.fromRGBO(15, 60, 40, 0.17),
    scrim: Color.fromRGBO(4, 28, 21, 0.38),
    heroStart: Color(0xFF003D32),
    heroMid: Color(0xFF005746),
    heroEnd: Color(0xFF0C7554),
    heroInk: Color(0xFFFFFFFF),
    heroMuted: Color.fromRGBO(255, 255, 255, 0.74),
    heroGlow: Color.fromRGBO(155, 216, 74, 0.34),
    glassTop: Color.fromRGBO(255, 255, 255, 0.20),
    glassBottom: Color.fromRGBO(255, 255, 255, 0.06),
    glassBorder: Color.fromRGBO(255, 255, 255, 0.24),
    glassHighlight: Color.fromRGBO(255, 255, 255, 0.30),
  );

  /// §2.2 Dark
  ///
  /// Tiga token tidak dicantumkan di tabel dark dan dilengkapi tanpa nilai
  /// baru: `lime` tetap `#9BD84A`, `heroInk` tetap putih, `mint` memakai
  /// `rgba(22,134,93,.18)` dari latar status disetujui §2.3.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0A1411),
    backgroundTint: Color(0xFF0E1B16),
    surface: Color(0xFF111F1A),
    surfaceAlt: Color(0xFF152720),
    elevated: Color(0xFF172A23),
    text: Color(0xFFECF6F0),
    muted: Color(0xFF9CB4A7),
    faint: Color(0xFF7C9488),
    primary: Color(0xFF8FE6B8),
    onPrimary: Color(0xFF06251B),
    leaf: Color(0xFF16865D),
    lime: Color(0xFF9BD84A),
    mint: Color.fromRGBO(22, 134, 93, 0.18),
    mintWash: Color(0xFF17342A),
    link: Color(0xFF8FE6B8),
    border: Color.fromRGBO(223, 243, 232, 0.09),
    borderStrong: Color.fromRGBO(223, 243, 232, 0.16),
    scrim: Color.fromRGBO(0, 12, 8, 0.58),
    heroStart: Color(0xFF00261F),
    heroMid: Color(0xFF004437),
    heroEnd: Color(0xFF0A6249),
    heroInk: Color(0xFFFFFFFF),
    heroMuted: Color.fromRGBO(255, 255, 255, 0.72),
    heroGlow: Color.fromRGBO(155, 216, 74, 0.20),
    glassTop: Color.fromRGBO(255, 255, 255, 0.13),
    glassBottom: Color.fromRGBO(255, 255, 255, 0.03),
    glassBorder: Color.fromRGBO(255, 255, 255, 0.16),
    glassHighlight: Color.fromRGBO(255, 255, 255, 0.18),
  );
}

/// Warna status di luar `ThemeExtension` karena tidak ikut animasi tema
/// (§10.2). Nilai dari §2.3.
@immutable
class AppStatusColors {
  const AppStatusColors({
    required this.approvedText,
    required this.approvedBackground,
    required this.approvedBorder,
    required this.pendingText,
    required this.pendingBackground,
    required this.pendingBorder,
    required this.rejectedText,
    required this.rejectedBackground,
    required this.rejectedBorder,
    required this.neutralText,
    required this.neutralBackground,
    required this.neutralBorder,
  });

  final Color approvedText;
  final Color approvedBackground;
  final Color approvedBorder;
  final Color pendingText;
  final Color pendingBackground;
  final Color pendingBorder;
  final Color rejectedText;
  final Color rejectedBackground;
  final Color rejectedBorder;
  final Color neutralText;
  final Color neutralBackground;
  final Color neutralBorder;

  /// Alias `badText` yang dipakai contoh §10.3 untuk `ColorScheme.error`.
  Color get badText => rejectedText;

  static AppStatusColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const AppStatusColors light = AppStatusColors(
    approvedText: Color(0xFF0F6B38),
    approvedBackground: Color(0xFFE4F6EA),
    approvedBorder: Color.fromRGBO(15, 107, 56, 0.18),
    pendingText: Color(0xFF8A4B08),
    pendingBackground: Color(0xFFFCF1DA),
    pendingBorder: Color.fromRGBO(138, 75, 8, 0.16),
    rejectedText: Color(0xFF9E1B1B),
    rejectedBackground: Color(0xFFFBE6E6),
    rejectedBorder: Color.fromRGBO(158, 27, 27, 0.16),
    neutralText: Color(0xFF5C6E65),
    neutralBackground: Color(0xFFEDF2EF),
    neutralBorder: Color.fromRGBO(15, 60, 40, 0.10),
  );

  static const AppStatusColors dark = AppStatusColors(
    approvedText: Color(0xFF8FE6B8),
    approvedBackground: Color.fromRGBO(22, 134, 93, 0.18),
    approvedBorder: Color.fromRGBO(143, 230, 184, 0.16),
    pendingText: Color(0xFFF2CD8A),
    pendingBackground: Color.fromRGBO(180, 120, 30, 0.18),
    pendingBorder: Color.fromRGBO(242, 205, 138, 0.16),
    rejectedText: Color(0xFFF6A6A6),
    rejectedBackground: Color.fromRGBO(185, 28, 28, 0.18),
    rejectedBorder: Color.fromRGBO(246, 166, 166, 0.16),
    neutralText: Color(0xFFA8BDB2),
    neutralBackground: Color.fromRGBO(223, 243, 232, 0.07),
    neutralBorder: Color.fromRGBO(223, 243, 232, 0.09),
  );
}
