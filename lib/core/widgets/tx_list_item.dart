import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import 'status_badge.dart';

/// Item baris transaksi dengan ikon jenis sampah, berat (kg), estimasi saldo, tanggal, dan StatusBadge
class TxListItem extends StatelessWidget {
  final String categoryName;
  final double weightKg;
  final double? amountRp;
  final String status;
  final DateTime createdAt;
  final VoidCallback? onTap;

  const TxListItem({
    super.key,
    required this.categoryName,
    required this.weightKg,
    this.amountRp,
    required this.status,
    required this.createdAt,
    this.onTap,
  });

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('plastik')) return Icons.local_drink_rounded;
    if (lower.contains('kertas') || lower.contains('karton')) return Icons.description_rounded;
    if (lower.contains('logam') || lower.contains('kaleng')) return Icons.hardware_rounded;
    if (lower.contains('kaca') || lower.contains('botol')) return Icons.wine_bar_rounded;
    if (lower.contains('elektronik')) return Icons.memory_rounded;
    return Icons.recycling_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLine, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(9, 92, 59, 0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Ikon Sampah dengan Lingkaran Mint
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.mintSoftBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getCategoryIcon(categoryName),
                    color: AppColors.primaryMain,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),

                // Kategori & Tanggal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Metrik Berat, Saldo, dan Badge Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(status: status),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${weightKg.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (amountRp != null && amountRp! > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${currencyFormat.format(amountRp)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryMain,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
