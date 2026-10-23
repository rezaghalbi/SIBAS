import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Peran kaca pada SIBAS Glass 2.0 (§7.2).
///
/// - [subtle]: panel ringkasan yang mengambang di atas konten.
/// - [dense]: navigasi bawah dan sheet yang harus tetap terbaca.
/// - [hero]: panel di dalam gradien hero.
enum GlassTone { subtle, dense, hero }

/// Satu-satunya sumber efek kaca (Apple Glassmorphism) di SIBAS.
///
/// ponytail: batasnya 1–2 `BackdropFilter` per layar; blur mahal di web
/// (CanvasKit). Turunkan biaya dengan tone `hero` (sigma 10), atau biarkan
/// `disableAnimations` mematikan blur sama sekali.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// Radius sudut. `null` mengikuti [tone]: 20 untuk [GlassTone.subtle] dan
  /// [GlassTone.hero], 24 untuk [GlassTone.dense] (§4, §7.2).
  final double? radius;

  /// Warna dasar pengganti gradien tone. Hanya untuk variasi terkontrol,
  /// mis. panel di atas kamera yang memakai `Colors.black`.
  final Color? tint;

  final GlassTone tone;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.tone = GlassTone.subtle,
    this.tint,
  });

  static const double blurSigma = 12;

  /// Blur hero sedikit lebih ringan (§7.2: 8–12).
  static const double heroBlurSigma = 10;

  /// Radius bawaan per tone (§4).
  static double radiusFor(GlassTone tone) {
    return tone == GlassTone.dense ? 24.0 : 20.0;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final colors = _Recipe.resolve(tone, palette, tint);
    final corner = BorderRadius.circular(radius ?? radiusFor(tone));

    // Hormati permintaan sistem "kurangi efek/animasi": render solid saja.
    final reduceEffects =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: reduceEffects
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.top, colors.bottom],
              ),
        // Fallback solid: tetap terbaca di atas gradien/foto apa pun (§7.3).
        color: reduceEffects ? _solidColor(tone, palette, tint) : null,
        borderRadius: corner,
        border: Border.all(color: colors.border, width: 1.2),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    // Inset highlight 1 px di sisi atas, dari tepi ke tepi (§7.2).
    final surface = Stack(
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
    );

    // Bayangan digambar di luar ClipRRect agar tidak ikut terpotong.
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: corner,
        boxShadow: _shadows(tone, palette),
      ),
      child: ClipRRect(
        borderRadius: corner,
        child: reduceEffects
            ? surface
            : BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: tone == GlassTone.hero ? heroBlurSigma : blurSigma,
                  sigmaY: tone == GlassTone.hero ? heroBlurSigma : blurSigma,
                ),
                child: surface,
              ),
      ),
    );

    if (margin == null) return panel;
    return Padding(padding: margin!, child: panel);
  }

  /// Warna solid saat blur dimatikan (§7.3). Opasitas .92–.96 agar teks
  /// tetap terbaca.
  static Color _solidColor(GlassTone tone, AppPalette palette, Color? tint) {
    if (tint != null) {
      return tint.withValues(alpha: 0.92);
    }

    final isDark = palette.brightness == Brightness.dark;

    if (tone == GlassTone.dense) {
      if (isDark) {
        return palette.surfaceAlt.withValues(alpha: 0.96);
      }
      return Colors.white.withValues(alpha: 0.96);
    }

    if (tone == GlassTone.hero) {
      if (isDark) {
        return palette.heroMid;
      }
      // Di atas hero: hijau pekat, bukan putih transparan.
      return const Color(0xFF07493A);
    }

    if (isDark) {
      return palette.surfaceAlt;
    }
    return Colors.white.withValues(alpha: 0.92);
  }

  /// Token bayangan §5. Light memakai `rgba(0,55,40,…)`; dark memakai hitam
  /// pekat tanpa bayangan ganda.
  static List<BoxShadow> _shadows(GlassTone tone, AppPalette palette) {
    const ink = Color.fromRGBO(0, 55, 40, 1);
    final dense = tone == GlassTone.dense;

    if (palette.brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.60),
          blurRadius: dense ? 44.0 : 24.0,
          spreadRadius: dense ? -24.0 : -14.0,
          offset: Offset(0, dense ? 22.0 : 8.0),
        ),
      ];
    }

    if (dense) {
      return [
        BoxShadow(
          color: ink.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: ink.withValues(alpha: 0.24),
          blurRadius: 44,
          spreadRadius: -24,
          offset: const Offset(0, 22),
        ),
      ];
    }

    return [
      BoxShadow(
        color: ink.withValues(alpha: 0.04),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: ink.withValues(alpha: 0.16),
        blurRadius: 24,
        spreadRadius: -14,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

/// Resep gradien dan border per tone (§7.2).
@immutable
class _Recipe {
  const _Recipe({
    required this.top,
    required this.bottom,
    required this.border,
  });

  final Color top;
  final Color bottom;
  final Color border;

  static _Recipe resolve(GlassTone tone, AppPalette palette, Color? tint) {
    final isDark = palette.brightness == Brightness.dark;
    final dense = tone == GlassTone.dense;

    // `tint` tetap jadi override terkontrol: alfa memakai nilai lama agar
    // panel kamera di `admin_scan_screen` tidak berubah rupa.
    if (tint != null) {
      return _Recipe(
        top: tint.withValues(alpha: isDark ? 0.10 : 0.15),
        bottom: tint.withValues(alpha: isDark ? 0.04 : 0.05),
        border: dense ? palette.border : palette.glassBorder,
      );
    }

    if (tone == GlassTone.subtle) {
      return _Recipe(
        top: palette.glassTop,
        bottom: palette.glassBottom,
        border: palette.glassBorder,
      );
    }

    if (tone == GlassTone.hero) {
      return _Recipe(
        top: Colors.white.withValues(alpha: 0.14),
        bottom: Colors.white.withValues(alpha: 0.08),
        border: Colors.white.withValues(alpha: 0.25),
      );
    }

    if (isDark) {
      return _Recipe(
        top: palette.surfaceAlt.withValues(alpha: 0.92),
        bottom: palette.surface.withValues(alpha: 0.84),
        border: Colors.white.withValues(alpha: 0.12),
      );
    }

    return _Recipe(
      top: Colors.white.withValues(alpha: 0.88),
      bottom: Colors.white.withValues(alpha: 0.74),
      border: palette.border,
    );
  }
}
