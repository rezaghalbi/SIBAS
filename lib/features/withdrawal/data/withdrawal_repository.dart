import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/api_guard.dart';
import '../domain/models/withdrawal_model.dart';

/// Repository penarikan saldo (withdrawal) mahasiswa & admin.
class WithdrawalRepository {
  final SupabaseClient _client;

  WithdrawalRepository(this._client);

  static const _selectWithRelations =
      '*, profiles:profiles!withdrawals_mahasiswa_id_fkey(full_name, nim), '
      'location:bank_locations(name, address, latitude, longitude)';

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
  Future<WithdrawalModel> createWithdrawal(
    double amount, {
    String? locationId,
  }) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'create_withdrawal',
        params: {
          'p_amount': amount,
          // Null berarti server memakai lokasi aktif pertama.
          'p_location_id': locationId,
        },
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

  /// Daftar pengajuan untuk admin.
  ///
  /// Status, lokasi, dan pencarian (nama/NIM) difilter di server agar tidak
  /// terpotong batas baris; `limit` dipakai untuk paginasi bertahap.
  Future<List<WithdrawalModel>> getAllWithdrawals({
    String? statusFilter,
    String? locationId,
    String query = '',
    int limit = 50,
  }) {
    return guardRequest(() async {
      var builder = _client.from('withdrawals').select(_selectWithRelations);
      if (statusFilter != null && statusFilter.isNotEmpty) {
        builder = builder.eq('status', statusFilter.toUpperCase());
      }
      if (locationId != null && locationId.isNotEmpty) {
        builder = builder.eq('location_id', locationId);
      }

      final needle = query.trim().replaceAll(RegExp(r'[,()*]'), ' ').trim();
      if (needle.isNotEmpty) {
        final pola = '%$needle%';
        builder = builder.or(
          'profiles.full_name.ilike.$pola,profiles.nim.ilike.$pola',
        );
      }

      final res = await builder
          .order('created_at', ascending: false)
          .limit(limit.clamp(1, 200));
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

  /// Rincian penarikan dari token QR (khusus admin).
  Future<Map<String, dynamic>> getWithdrawalByQr(String token) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'penarikan_by_qr',
        params: {'p_token': token},
      );
      if (res is Map) return res.cast<String, dynamic>();
      throw StateError('Respons penarikan_by_qr tidak dikenali.');
    });
  }

  /// Setujui penarikan lewat token QR (khusus admin). Mengembalikan status akhir.
  Future<String> approveWithdrawalByQr(String token) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'tarik_by_qr',
        params: {'p_token': token},
      );
      if (res is Map) return res['status'] as String? ?? 'APPROVED';
      throw StateError('Respons tarik_by_qr tidak dikenali.');
    });
  }
}
