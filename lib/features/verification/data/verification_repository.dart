"import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/admin_metrics_model.dart';

/// Repository operasional Admin: metrik, verifikasi RPC, daftar transaksi.
class VerificationRepository {
  final SupabaseClient _client;

  VerificationRepository(this._client);

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
      final weight = (item['weight'] != null) ? (item['weight'] as num).toDouble() : 0.0;
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
"