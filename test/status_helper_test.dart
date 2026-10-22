import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/core/constants/colors.dart';
import 'package:sibas/core/utils/status_helper.dart';

void main() {
  group('TransactionStatusHelper.fromString', () {
    test('memetakan string status resmi', () {
      expect(
        TransactionStatusHelper.fromString('APPROVED'),
        TransactionStatus.approved,
      );
      expect(
        TransactionStatusHelper.fromString('REJECTED'),
        TransactionStatus.rejected,
      );
      expect(
        TransactionStatusHelper.fromString('EXPIRED'),
        TransactionStatus.expired,
      );
      // Huruf kecil tetap dikenali.
      expect(
        TransactionStatusHelper.fromString('approved'),
        TransactionStatus.approved,
      );
    });

    test('PENDING, null, dan nilai tak dikenal jatuh ke pending', () {
      for (final value in ['PENDING', null, 'aneh', '']) {
        expect(
          TransactionStatusHelper.fromString(value),
          TransactionStatus.pending,
          reason: 'input: $value',
        );
      }
    });
  });

  group('TransactionStatusHelper.toDisplayLabel', () {
    test('label sesuai matriks resmi', () {
      expect(
        TransactionStatusHelper.toDisplayLabel('PENDING'),
        'Menunggu Verifikasi',
      );
      expect(TransactionStatusHelper.toDisplayLabel('APPROVED'), 'Disetujui');
      expect(TransactionStatusHelper.toDisplayLabel('REJECTED'), 'Ditolak');
      expect(TransactionStatusHelper.toDisplayLabel('EXPIRED'), 'Kedaluwarsa');
      expect(
        TransactionStatusHelper.toDisplayLabel(null),
        'Menunggu Verifikasi',
      );
    });
  });

  group('TransactionStatusHelper.getStatusColor', () {
    test('warna mengikuti palet status', () {
      expect(
        TransactionStatusHelper.getStatusColor('PENDING'),
        AppColors.statusPending,
      );
      expect(
        TransactionStatusHelper.getStatusColor('APPROVED'),
        AppColors.statusApproved,
      );
      expect(
        TransactionStatusHelper.getStatusColor('REJECTED'),
        AppColors.statusRejected,
      );
      expect(
        TransactionStatusHelper.getStatusColor('EXPIRED'),
        AppColors.statusExpired,
      );
      // null ikut pending
      expect(
        TransactionStatusHelper.getStatusColor(null),
        AppColors.statusPending,
      );
    });
  });
}
