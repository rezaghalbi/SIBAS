import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';

/// Card saldo transparan putih 14% di atas background gradien sesuai locked design system
/// Mendukung penanganan dinamis jika tarif Rp/kg belum diset/bernilai 0 (hanya tampilkan kg)
class SaldoHeroCard extends StatelessWidget {
  final double balance;
  final double totalWeightKg;
  final bool hasActiveRate; // Jika false atau rate 0, sembunyikan card nominal saldo Rp
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
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.heroCardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.heroCardBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasActiveRate ? 'Saldo Tabungan Sampah' : 'Total Sampah Terkumpul',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SIBAS POLTEKKES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nilai Utama (Saldo Rp atau Berat kg jika tarif tidak aktif)
          if (hasActiveRate) ...[
            Text(
              currencyFormatter.format(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.scale_rounded,
                  color: Colors.white.withOpacity(0.85),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Total Kontribusi: ${totalWeightKg.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Fokus berat (kg) ketika tarif Rp/kg belum diset / 0
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  totalWeightKg.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'kg',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fokus metrik penimbangan sampah daur ulang',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
              ),
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
                  foregroundColor: AppColors.primaryMain,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.qr_code_rounded, size: 20),
                label: const Text(
                  'Setor Sampah Sekarang',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
