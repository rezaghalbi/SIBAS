import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Chip status yang mengikuti tema light/dark (§2.3).
///
/// - Menunggu Verifikasi: `pending`
/// - Disetujui / Diterima: `approved`
/// - Ditolak / Kedaluwarsa: `rejected`
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

    final palette = AppPalette.of(context);
    final colors = AppStatusColors.of(palette.brightness);

    Color textColor;
    Color bgColor;
    String label;

    final normalized = status.toUpperCase().trim();

    switch (normalized) {
      case 'APPROVED':
      case 'DITERIMA':
      case 'DISETUJUI':
        textColor = colors.approvedText;
        bgColor = colors.approvedBackground;
        label = customLabel ?? 'Disetujui';
        break;

      case 'REJECTED':
      case 'DITOLAK':
        textColor = colors.rejectedText;
        bgColor = colors.rejectedBackground;
        label = customLabel ?? 'Ditolak';
        break;

      case 'EXPIRED':
      case 'KEDALUWARSA':
        textColor = colors.rejectedText;
        bgColor = colors.rejectedBackground;
        label = customLabel ?? 'Kedaluwarsa';
        break;

      case 'PENDING':
      case 'MENUNGGU':
      default:
        textColor = colors.pendingText;
        bgColor = colors.pendingBackground;
        label = customLabel ?? 'Menunggu Verifikasi';
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
