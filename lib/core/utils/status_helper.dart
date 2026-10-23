import 'package:flutter/material.dart';
import '../theme/sibas_colors.dart';

/// Helper pemetaan status transaksi sesuai matriks resmi di .antigravity/prd.md
enum TransactionStatus {
  pending,
  approved,
  rejected,
  expired,
}

class TransactionStatusHelper {
  TransactionStatusHelper._();

  /// Mengubah status string database menjadi enum TransactionStatus
  static TransactionStatus fromString(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
        return TransactionStatus.approved;
      case 'REJECTED':
        return TransactionStatus.rejected;
      case 'EXPIRED':
        return TransactionStatus.expired;
      case 'PENDING':
      default:
        return TransactionStatus.pending;
    }
  }

  /// Pemetaan label status UI resmi SIBAS
  /// 'PENDING' -> 'Menunggu Verifikasi'
  /// 'APPROVED' -> 'Disetujui'
  /// 'REJECTED' -> 'Ditolak'
  /// 'EXPIRED' -> 'Kedaluwarsa'
  static String toDisplayLabel(String? status) {
    final parsed = fromString(status);
    switch (parsed) {
      case TransactionStatus.pending:
        return 'Menunggu Verifikasi';
      case TransactionStatus.approved:
        return 'Disetujui';
      case TransactionStatus.rejected:
        return 'Ditolak';
      case TransactionStatus.expired:
        return 'Kedaluwarsa';
    }
  }

  /// Warna badge status untuk UI
  static Color getStatusColor(String? status) {
    final parsed = fromString(status);
    switch (parsed) {
      case TransactionStatus.pending:
        return SibasColors.status.pendingText;
      case TransactionStatus.approved:
        return SibasColors.status.approvedText;
      case TransactionStatus.rejected:
        return SibasColors.status.rejectedText;
      case TransactionStatus.expired:
        return SibasColors.status.neutralText;
    }
  }
}
