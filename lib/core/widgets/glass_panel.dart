import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/colors.dart';

/// Satu-satunya sumber efek kaca (Apple Glassmorphism) di SIBAS.
///
/// ponytail: batasnya 1–2 `BackdropFilter` per layar; blur mahal di web
/// (CanvasKit). Naikkan performa dengan menurunkan [blurSigma] (12 → 8) atau
/// kirim `tint` solid dan biarkan `disableAnimations` mematikan blur.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? tint;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 20,
    this.tint,
  });

  static const double blurSigma = 12;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseTint = tint ?? (isDark ? Colors.black : Colors.white);

    // Hormati permintaan sistem "kurangi efek/animasi": render solid saja.
    final reduceEffects = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final decoration = BoxDecoration(
      gradient: reduceEffects
          ? null
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseTint.withValues(alpha: isDark ? 0.10 : 0.15),
                baseTint.withValues(alpha: isDark ? 0.04 : 0.05),
              ],
            ),
      // Fallback solid: tetap terbaca di atas gradien/foto apa pun.
      color: reduceEffects
          ? (isDark
              ? const Color(0xFF1F2C27)
              : Colors.white.withValues(alpha: 0.92))
          : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.2),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: (isDark ? Colors.black : AppColors.primaryDark)
              .withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ],
    );

    final content = DecoratedBox(
      decoration: decoration,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    final panel = reduceEffects
        ? content
        : ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: content,
            ),
          );

    if (margin == null) return panel;
    return Padding(padding: margin!, child: panel);
  }
}
