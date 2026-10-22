import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// HeroHeader dengan gradien hijau resmi SIBAS, lekukan bawah, branding, dan sapaan profil
class HeroHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottomContent;

  /// Tanda/logo di kiri judul. Bila null dipakai badge ikon bawaan.
  final Widget? mark;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomBorderRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris Branding / User Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      // Mark kustom (mis. logo) atau badge ikon bawaan.
                      mark ?? const _DefaultMark(),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
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
                                color: Colors.white.withValues(alpha: 0.85),
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
      ),
    );
  }
}

/// Badge ikon bawaan saat pemanggil tidak memberi `mark`.
class _DefaultMark extends StatelessWidget {
  const _DefaultMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: const Center(
        child: Icon(Icons.eco_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}
