import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/colors.dart';
import '../theme/app_palette.dart';
import 'glass_panel.dart';

/// Panel saldo di dalam hero (§10.8): kaca tone `hero` dengan teks hero.
///
/// Bila tarif Rp/kg belum diset, fokus berpindah ke berat (kg) saja.
class SaldoHeroCard extends StatelessWidget {
  final double balance;
  final double totalWeightKg;
  final bool hasActiveRate; // Jika false atau rate 0, sembunyikan nominal Rp
  final VoidCallback? onSetorPressed;

  const SaldoHeroCard({
    super.key,
    required this.balance,
    required this.totalWeightKg,
    this.hasActiveRate = true,
    this.onSetorPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final ink = palette.heroInk;
    final muted = palette.heroMuted;

    const nominal = <FontFeature>[FontFeature.tabularFigures()];
    final label = hasActiveRate
        ? 'Saldo Tabungan Sampah'
        : 'Total Sampah Terkumpul';

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return SizedBox(
      width: double.infinity,
      child: GlassPanel(
        tone: GlassTone.hero,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Label boleh menyusut; chip di kanan tidak pernah dipotong.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.90),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'SIBAS POLTEKKES',
                    maxLines: 1,
                    style: TextStyle(
                      color: ink,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nilai utama: saldo Rp atau berat kg bila tarif belum aktif.
            if (hasActiveRate) ...[
              Text(
                currencyFormatter.format(balance),
                style: TextStyle(
                  color: ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontFeatures: nominal,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.scale_rounded, color: muted, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Total Kontribusi: ${totalWeightKg.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFeatures: nominal,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    totalWeightKg.toStringAsFixed(1),
                    style: TextStyle(
                      color: ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFeatures: nominal,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'kg',
                    style: TextStyle(
                      color: ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Fokus metrik penimbangan sampah daur ulang',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],

            if (onSetorPressed != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onSetorPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.qr_code_rounded, size: 20),
                  label: const Text(
                    'Setor Sampah Sekarang',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
