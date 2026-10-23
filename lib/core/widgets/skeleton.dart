import 'package:flutter/material.dart';

import '../theme/sibas_colors.dart';
import 'surface_card.dart';

/// Blok abu-abu pengganti konten saat memuat.
///
/// Sengaja tanpa animasi: satu kerangka statis lebih murah di web (CanvasKit)
/// daripada puluhan animasi opacity yang berjalan bersamaan.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SibasColors.border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Kerangka daftar: beberapa kartu dengan baris teks pengganti.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.items = 3, this.lines = 3});

  final int items;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBlock(width: 120, height: 14),
                  const SizedBox(height: 10),
                  for (var l = 0; l < lines; l++) ...[
                    SkeletonBlock(width: l == lines - 1 ? 160 : null, height: 10),
                    if (l < lines - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
