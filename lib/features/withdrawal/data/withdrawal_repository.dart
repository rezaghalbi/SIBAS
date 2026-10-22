import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/api_guard.dart';
import '../domain/models/withdrawal_model.dart';

/// Repository penarikan saldo (withdrawal) mahasiswa & admin.
class WithdrawalRepository {
  final SupabaseClient _client;

  WithdrawalRepository(this._client);

  static const _selectWithRelations =
      '*, profiles:profiles!withdrawals_mahasiswa_id_fkey(full_name, nim)';

  /// Saldo yang boleh ditarik. Dihitung server lewat RPC available_balance.
  Future<double> getAvailableBalance(String userId) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'available_balance',
        params: {'p_user': userId},
      );
      if (res == null) return 0.0;
      return (res as num).toDouble();
    });
  }

  /// Ajukan penarikan. Nominal & status awal ditentukan server.
  Future<WithdrawalModel> createWithdrawal(double amount) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'create_withdrawal',
        params: {'p_amount': amount},
      );

      if (res is Map) {
        return WithdrawalModel.fromJson(res.cast<String, dynamic>());
      }
      // RPC yang hanya membalas id: ambil barisnya agar UI dapat data lengkap.
      if (res is String) {
        final row = await _client
            .from('withdrawals')
            .select(_selectWithRelations)
            .eq('id', res)
            .maybeSingle();
        if (row == null) {
          throw StateError('Pengajuan penarikan tidak ditemukan setelah dibuat.');
        }
        return WithdrawalModel.fromJson(row);
      }
      throw StateError('Respons create_withdrawal tidak dikenali.');
    });
  }

  /// Riwayat penarikan milik satu mahasiswa, terbaru dulu.
  Future<List<WithdrawalModel>> getStudentWithdrawals(String userId) {
    return guardRequest(() async {
      final res = await _client
          .from('withdrawals')
          .select(_selectWithRelations)
          .eq('mahasiswa_id', userId)
          .order('created_at', ascending: false);

      return (res as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(WithdrawalModel.fromJson)
          .toList();
    });
  }

  /// Daftar pengajuan untuk admin, opsional difilter status.
  Future<List<WithdrawalModel>> getAllWithdrawals({String? statusFilter}) {
    return guardRequest(() async {
      var builder = _client.from('withdrawals').select(_selectWithRelations);
      if (statusFilter != null && statusFilter.isNotEmpty) {
        builder = builder.eq('status', statusFilter.toUpperCase());
      }

      final res = await builder.order('created_at', ascending: false).limit(200);
      return (res as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(WithdrawalModel.fromJson)
          .toList();
    });
  }

  /// Setujui penarikan. Mengembalikan status akhir dari server.
  Future<String> approveWithdrawal(String id) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'approve_withdrawal',
        params: {'p_withdrawal_id': id},
      );
      return (res as Map?)?['status'] as String? ?? 'APPROVED';
    });
  }

  /// Tolak penarikan dengan alasan wajib. Saldo tidak berubah.
  Future<String> rejectWithdrawal(String id, String reason) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'reject_withdrawal',
        params: {'p_withdrawal_id': id, 'p_reason': reason},
      );
      return (res as Map?)?['status'] as String? ?? 'REJECTED';
    });
  }
}
