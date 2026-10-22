import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/admin_metrics_model.dart';

/// Repository operasional Admin: metrik, verifikasi RPC, daftar transaksi.
class VerificationRepository {
  final SupabaseClient _client;

  VerificationRepository(this._client);

  static const _selectWithRelations =
      '*, profiles:profiles!transactions_mahasiswa_id_fkey(full_name, nim), '
      'trash_types(name, price_per_kg)';

  /// Statistik metrik dashboard admin.
  /// Tanpa angka pengganti: kegagalan query jadi AsyncError di provider.
  Future<AdminMetricsModel> getAdminMetrics() async {
    final res = await _client.from('transactions').select('weight, status');
    final list = res as List<dynamic>;

    double totalKg = 0.0;
    int pending = 0;
    int approved = 0;
    int rejected = 0;

    for (final item in list) {
      final status = (item['status'] as String?)?.toUpperCase() ?? 'PENDING';
      final weight =
          (item['weight'] != null) ? (item['weight'] as num).toDouble() : 0.0;
      if (status == 'APPROVED') {
        approved++;
        totalKg += weight;
      } else if (status == 'REJECTED') {
        rejected++;
      } else if (status == 'PENDING') {
        pending++;
      }
    }

    return AdminMetricsModel(
      totalWeightKg: totalKg,
      pendingCount: pending,
      approvedCount: approved,
      rejectedCount: rejected,
    );
  }

  /// Daftar transaksi untuk admin. Filter status di server, pencarian di klien
  /// agar bisa mencocokkan nama/NIM hasil join tanpa query PostgREST bertingkat.
  Future<List<Map<String, dynamic>>> getAllTransactions({
    String query = '',
    String? statusFilter,
  }) async {
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
  }

  /// Membuka transaksi dari hasil scan QR. Validasi role, token, dan status
  /// dilakukan di server oleh RPC get_transaction_by_qr.
  Future<Map<String, dynamic>?> getTransactionForVerification(
    String code,
  ) async {
    final res = await _client.rpc(
      'get_transaction_by_qr',
      params: {'p_code': code.trim()},
    );
    if (res == null) return null;
    return res as Map<String, dynamic>;
  }

  /// Menyetujui setoran. Saldo, total berat, waktu, dan verifikator dihitung
  /// server. Berat pengajuan tidak boleh diubah admin (DOCX §4).
  Future<void> approveTransaction({
    required String transactionId,
    required String adminId,
    required double verifiedWeightKg,
  }) async {
    // ponytail: adminId & verifiedWeightKg tidak dikirim; server memakai
    // auth.uid() dan berat pengajuan. Rapikan signature saat Fase 5.
    await _client.rpc(
      'approve_transaction',
      params: {'p_transaction_id': transactionId},
    );
  }

  /// Menolak setoran dengan alasan wajib. Saldo & total berat tidak berubah.
  Future<void> rejectTransaction({
    required String transactionId,
    required String adminId,
    required String reason,
  }) async {
    // ponytail: adminId tidak dikirim; server memakai auth.uid().
    await _client.rpc(
      'reject_transaction',
      params: {'p_transaction_id': transactionId, 'p_reason': reason},
    );
  }
}
