import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/features/withdrawal/domain/models/withdrawal_model.dart';

Map<String, dynamic> _row({Object? profiles}) => {
  'id': 'wd-1',
  'mahasiswa_id': 'mhs-1',
  'amount': 150000,
  'status': 'PENDING',
  'rejection_reason': null,
  'verified_at': null,
  'created_at': '2026-01-02T03:04:05Z',
  if (profiles != null) 'profiles': profiles,
};

void main() {
  group('WithdrawalModel.fromJson', () {
    test('baris tanpa relasi profiles', () {
      final model = WithdrawalModel.fromJson(_row());

      expect(model.id, 'wd-1');
      expect(model.mahasiswaId, 'mhs-1');
      expect(model.amount, 150000.0);
      expect(model.status, 'PENDING');
      expect(model.rejectionReason, isNull);
      expect(model.verifiedAt, isNull);
      expect(model.createdAt, DateTime.parse('2026-01-02T03:04:05Z'));
      expect(model.studentName, isNull);
      expect(model.studentNim, isNull);
    });

    test('baris dengan profiles terisi nama dan nim', () {
      final model = WithdrawalModel.fromJson(
        _row(profiles: {'full_name': 'Budi Santoso', 'nim': '20230001'}),
      );

      expect(model.studentName, 'Budi Santoso');
      expect(model.studentNim, '20230001');
    });

    test('profiles null atau bukan map tidak melempar', () {
      final nullProfile =
          WithdrawalModel.fromJson(_row(profiles: null));
      expect(nullProfile.studentName, isNull);
      expect(nullProfile.studentNim, isNull);

      // Relasi bisa datang sebagai list (PostgREST to-one tetap array).
      final listProfile = WithdrawalModel.fromJson(
        _row(
          profiles: [
            {'full_name': 'Budi', 'nim': '1'},
          ],
        ),
      );
      expect(listProfile.studentName, isNull);
      expect(listProfile.studentNim, isNull);

      final stringProfile =
          WithdrawalModel.fromJson(_row(profiles: 'bukan map'));
      expect(stringProfile.studentName, isNull);
    });
  });

  group('getter status', () {
    test('cocok untuk huruf besar dan kecil', () {
      final pending = WithdrawalModel.fromJson(_row());
      expect(pending.isPending, isTrue);
      expect(pending.isApproved, isFalse);
      expect(pending.isRejected, isFalse);

      final approved = WithdrawalModel.fromJson(
        _row(profiles: null)..['status'] = 'approved',
      );
      expect(approved.isApproved, isTrue);

      final rejected = WithdrawalModel.fromJson(
        _row(profiles: null)..['status'] = 'Rejected',
      );
      expect(rejected.isRejected, isTrue);
    });
  });
}
