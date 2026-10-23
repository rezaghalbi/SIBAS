import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'content_width.dart';

/// Hero inset SIBAS Glass 2.0 (§10.8): kartu radius 28 dengan gradien hero,
/// glow radial, dan teks hero. Tidak lagi menempel penuh ke tepi layar.
class HeroHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottomContent;

  /// Tanda/logo di kiri judul. Bila null dipakai badge ikon bawaan.
  final Widget? mark;

  /// Dipertahankan agar pemanggil lama tetap kompatibel. V2 memakai radius
  /// 28 seragam untuk hero (§4), jadi nilai ini tidak lagi dipakai.
  final double bottomBorderRadius;

  const HeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottomContent,
    this.mark,
    this.bottomBorderRadius = 32.0,
  });

  static const double _radius = 28;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final reduceEffects =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final gutter = ContentWidth.gutterFor(MediaQuery.sizeOf(context).width);
    final corner = BorderRadius.circular(_radius);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: corner,
              // Arah 150° seperti prototipe web.
              gradient: LinearGradient(
                begin: const Alignment(-0.5, -0.87),
                end: const Alignment(0.5, 0.87),
                colors: [
                  palette.heroStart,
                  palette.heroMid,
                  palette.heroEnd,
                ],
                stops: const [0, 0.55, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.60)
                      : const Color.fromRGBO(0, 60, 45, 0.50),
                  blurRadius: 48,
                  spreadRadius: -24,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: corner,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  if (!reduceEffects)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.9, -1),
                              radius: 1.1,
                              colors: [
                                palette.heroGlow,
                                palette.heroGlow.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                mark ?? _DefaultMark(ink: palette.heroInk),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: palette.heroInk,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    if (subtitle != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle!,
                                        style: TextStyle(
                                          color: palette.heroMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            if (trailing != null) trailing!,
                          ],
                        ),
                        if (bottomContent != null) ...[
                          const SizedBox(height: 20),
                          bottomContent!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge ikon bawaan saat pemanggil tidak memberi `mark`.
class _DefaultMark extends StatelessWidget {
  const _DefaultMark({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ink.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(Icons.eco_rounded, color: ink, size: 24),
      ),
    );
  }
}
