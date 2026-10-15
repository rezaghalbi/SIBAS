import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Chip status dengan visual presisi sesuai prototype .antigravity/design_system.md
/// - Menunggu Validasi: Text #B45309, BG #FEF3C7
/// - Disetujui / Diterima: Text #15803D, BG #DCFCE7
/// - Ditolak / Kedaluwarsa: Text #B91C1C, BG #FEE2E2
class StatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;
    String label;

    final normalized = status.toUpperCase().trim();

    switch (normalized) {
      case 'APPROVED':
      case 'DITERIMA':
      case 'DISETUJUI':
        textColor = AppColors.statusApprovedText;
        bgColor = AppColors.statusApprovedBg;
        label = customLabel ?? 'Disetujui';
        break;

      case 'REJECTED':
      case 'DITOLAK':
        textColor = AppColors.statusRejectedText;
        bgColor = AppColors.statusRejectedBg;
        label = customLabel ?? 'Ditolak';
        break;

      case 'EXPIRED':
      case 'KEDALUWARSA':
        textColor = AppColors.statusRejectedText;
        bgColor = AppColors.statusRejectedBg;
        label = customLabel ?? 'Kedaluwarsa';
        break;

      case 'PENDING':
      case 'MENUNGGU':
      default:
        textColor = AppColors.statusPendingText;
        bgColor = AppColors.statusPendingBg;
        label = customLabel ?? 'Menunggu Validasi';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
