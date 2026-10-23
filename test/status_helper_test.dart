import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/core/theme/app_palette.dart';
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
        AppStatusColors.light.pendingText,
      );
      expect(
        TransactionStatusHelper.getStatusColor('APPROVED'),
        AppStatusColors.light.approvedText,
      );
      expect(
        TransactionStatusHelper.getStatusColor('REJECTED'),
        AppStatusColors.light.rejectedText,
      );
      expect(
        TransactionStatusHelper.getStatusColor('EXPIRED'),
        AppStatusColors.light.neutralText,
      );
      // null ikut pending
      expect(
        TransactionStatusHelper.getStatusColor(null),
        AppStatusColors.light.pendingText,
      );
    });
  });
}
