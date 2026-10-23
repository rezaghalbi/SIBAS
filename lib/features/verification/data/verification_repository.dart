import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/api_guard.dart';
import '../domain/models/admin_metrics_model.dart';

/// Repository operasional Admin: metrik, verifikasi RPC, daftar transaksi.
class VerificationRepository {
  final SupabaseClient _client;

  VerificationRepository(this._client);

  static const _selectWithRelations =
      '*, profiles:profiles!transactions_mahasiswa_id_fkey(full_name, nim), '
      'trash_types(name, price_per_kg), '
      'location:bank_locations(name, address, latitude, longitude)';

  /// Statistik metrik dashboard admin, dihitung di server lewat RPC
  /// `admin_metrics` (klien tidak lagi menarik seluruh baris transaksi).
  /// Tanpa angka pengganti: kegagalan query jadi AsyncError di provider.
  Future<AdminMetricsModel> getAdminMetrics() {
    return guardRequest(() async {
      final res = await _client.rpc('admin_metrics');
      final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};

      double asDouble(Object? value) =>
          value is num ? value.toDouble() : 0.0;
      int asInt(Object? value) => value is num ? value.toInt() : 0;

      return AdminMetricsModel(
        totalWeightKg: asDouble(map['total_weight_kg']),
        pendingCount: asInt(map['pending_count']),
        approvedCount: asInt(map['approved_count']),
        rejectedCount: asInt(map['rejected_count']),
      );
    });
  }

  /// Daftar transaksi untuk admin. Filter status di server, pencarian di klien
  /// agar bisa mencocokkan nama/NIM hasil join tanpa query PostgREST bertingkat.
  Future<List<Map<String, dynamic>>> getAllTransactions({
    String query = '',
    String? statusFilter,
  }) {
    return guardRequest(() async {
      var builder = _client.from('transactions').select(_selectWithRelations);
      if (statusFilter != null && statusFilter.isNotEmpty) {
        builder = builder.eq('status', statusFilter.toUpperCase());
      }

      final res = await builder.order('created_at', ascending: false).limit(200);
      final rows = (res as List<dynamic>).cast<Map<String, dynamic>>();

      final needle = query.trim().toLowerCase();
      if (needle.isEmpty) return rows;

      return rows.where((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        return (profile?['full_name'] as String? ?? '')
                .toLowerCase()
                .contains(needle) ||
            (profile?['nim'] as String? ?? '').toLowerCase().contains(needle) ||
            (row['tx_code'] as String? ?? '').toLowerCase().contains(needle) ||
            (row['id'] as String? ?? '').toLowerCase().contains(needle);
      }).toList();
    });
  }

  /// Membuka transaksi dari hasil scan QR. Validasi role, token, dan status
  /// dilakukan di server oleh RPC get_transaction_by_qr.
  Future<Map<String, dynamic>?> getTransactionForVerification(
    String code,
  ) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'get_transaction_by_qr',
        params: {'p_code': code.trim()},
      );
      if (res == null) return null;
      return res as Map<String, dynamic>;
    });
  }

  /// Menyetujui setoran. Saldo, total berat, waktu, dan verifikator dihitung
  /// server. Berat pengajuan tidak boleh diubah admin (DOCX §4).
  ///
  /// Mengembalikan status akhir: 'APPROVED', atau 'EXPIRED' bila QR sudah
  /// kedaluwarsa (server menandai EXPIRED, bukan melempar exception).
  Future<String> approveTransaction({required String transactionId}) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'approve_transaction',
        params: {'p_transaction_id': transactionId},
      );
      return (res as Map?)?['status'] as String? ?? 'APPROVED';
    });
  }

  /// Menolak setoran dengan alasan wajib. Saldo & total berat tidak berubah.
  Future<String> rejectTransaction({
    required String transactionId,
    required String reason,
  }) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'reject_transaction',
        params: {'p_transaction_id': transactionId, 'p_reason': reason},
      );
      return (res as Map?)?['status'] as String? ?? 'REJECTED';
    });
  }
}
