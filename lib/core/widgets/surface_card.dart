import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Peran kartu statis pada SIBAS Glass 2.0.
///
/// Keduanya tanpa blur; pembedanya hanya alfa permukaan.
///
/// - [card]: kartu konten di atas latar halaman. Putih `.72 → .52` (light)
///   dan putih `.06 → .02` (dark). Latar halaman masih samar terlihat, jadi
///   kartu tidak jatuh menjadi putih polos.
/// - [subtle]: panel sekunder di dalam kartu, alfa lebih rendah. Putih
///   `.42 → .28` (light) dan putih `.04 → .015` (dark).
enum SurfaceTone { card, subtle }

/// Kartu "kaca statis": gradien tipis, border 1 px, inset highlight, tanpa
/// `BackdropFilter`.
///
/// Ini pasangan `GlassPanel` untuk konten. Blur hanya dipakai lapisan
/// mengambang (hero, nav, sheet) dan dibatasi 1–2 per layar, jadi kartu
/// konten tidak boleh menambah `BackdropFilter`; pemerataan bahasa visual
/// dilakukan lewat gradien, border, dan highlight yang sama.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Radius sudut, bawaan 20 (§4).
  final double radius;

  /// Pengganti gradien tone, mis. `AppStatusColors.approvedBackground`.
  /// Border, inset highlight, dan shadow tetap netral agar tetap satu bahasa.
  final Color? color;

  final SurfaceTone tone;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 20,
    this.color,
    this.tone = SurfaceTone.card,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final recipe = _SurfaceRecipe.resolve(tone, palette, color);
    final corner = BorderRadius.circular(radius);

    // Permukaan: gradien per tone + garis 1 px. Tanpa blur.
    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [recipe.top, recipe.bottom],
        ),
        borderRadius: corner,
        border: Border.all(color: recipe.border, width: 1.0),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    // Inset highlight 1 px di sisi atas, dari tepi ke tepi (§7.2).
    final surface = ClipRRect(
      borderRadius: corner,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          content,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      palette.glassHighlight.withValues(alpha: 0),
                      palette.glassHighlight,
                      palette.glassHighlight.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Bayangan digambar di luar ClipRRect agar tidak ikut terpotong.
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corner,
        boxShadow: recipe.shadows,
      ),
      child: surface,
    );

    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
  }
}

/// Resep gradien, border, dan shadow per tone.
///
/// Alfa permukaan dipasang langsung di atas latar halaman (bukan ditumpuk
/// pada `surface` solid), sehingga tint aurora tetap samar terlihat. Di light
/// kompositnya sekitar `#FCFDFC`; teks `#12201A` tetap kontras tinggi.
@immutable
class _SurfaceRecipe {
  const _SurfaceRecipe({
    required this.top,
    required this.bottom,
    required this.border,
    required this.shadows,
  });

  final Color top;
  final Color bottom;
  final Color border;
  final List<BoxShadow> shadows;

  /// Tinta bayangan light §5: `rgba(0,55,40,…)`.
  static const Color _ink = Color.fromRGBO(0, 55, 40, 1);

  static _SurfaceRecipe resolve(
    SurfaceTone tone,
    AppPalette palette,
    Color? color,
  ) {
    final isDark = palette.brightness == Brightness.dark;
    final isCard = tone == SurfaceTone.card;

    // `color` hanya mengganti lapisan permukaan. Border dan shadow tetap
    // mengikuti tema supaya panel status tidak keluar dari bahasa visual.
    if (color != null) {
      return _SurfaceRecipe(
        top: color,
        bottom: color.withValues(alpha: 0.88),
        border: isDark ? Colors.white.withValues(alpha: 0.12) : palette.border,
        shadows: isCard ? _shadow(isDark) : const [],
      );
    }

    if (isDark) {
      return _SurfaceRecipe(
        top: Colors.white.withValues(alpha: isCard ? 0.06 : 0.04),
        bottom: Colors.white.withValues(alpha: isCard ? 0.02 : 0.015),
        border: Colors.white.withValues(alpha: isCard ? 0.14 : 0.10),
        shadows: isCard ? _shadow(true) : const [],
      );
    }

    return _SurfaceRecipe(
      top: Colors.white.withValues(alpha: isCard ? 0.72 : 0.42),
      bottom: Colors.white.withValues(alpha: isCard ? 0.52 : 0.28),
      border: isCard ? palette.border : palette.border.withValues(alpha: 0.07),
      shadows: isCard ? _shadow(false) : const [],
    );
  }

  /// Token `sm` §5: dua lapis rendah di light, satu lapis hitam di dark.
  /// `subtle` tidak memakai bayangan karena sudah berada di dalam kartu.
  static List<BoxShadow> _shadow(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 20,
          spreadRadius: -12,
          offset: const Offset(0, 8),
        ),
      ];
    }

    return [
      BoxShadow(
        color: _ink.withValues(alpha: 0.04),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: _ink.withValues(alpha: 0.16),
        blurRadius: 24,
        spreadRadius: -14,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
