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
  Future<AdminMetricsModel> getAdminMetrics({String? locationId}) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'admin_metrics',
        params: {'p_location_id': locationId},
      );
      final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};

      double asDouble(Object? value) =>
          value is num ? value.toDouble() : 0.0;
      int asInt(Object? value) => value is num ? value.toInt() : 0;

      final lokasi = (map['locations'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((row) => LocationMetric.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      return AdminMetricsModel(
        totalWeightKg: asDouble(map['total_weight_kg']),
        pendingCount: asInt(map['pending_count']),
        approvedCount: asInt(map['approved_count']),
        rejectedCount: asInt(map['rejected_count']),
        locationId: map['location_id'] as String?,
        locations: lokasi,
      );
    });
  }

  /// Ukuran satu halaman saat menarik seluruh data untuk ekspor.
  static const _pageSize = 1000;

  /// Daftar transaksi untuk admin.
  ///
  /// Pencarian, status, lokasi, dan rentang tanggal difilter **di server**
  /// supaya hasil tidak terpotong oleh batas baris. `limit` dipakai untuk
  /// paginasi bertahap.
  Future<List<Map<String, dynamic>>> getAllTransactions({
    String query = '',
    String? statusFilter,
    String? locationId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    return guardRequest(
      () => _fetchTransactions(
        query: query,
        statusFilter: statusFilter,
        locationId: locationId,
        startDate: startDate,
        endDate: endDate,
        maxRows: limit.clamp(1, 5000),
      ),
    );
  }

  /// Seluruh transaksi yang cocok dengan filter, tanpa batas 200 baris.
  /// Dipakai ekspor CSV: halaman 1000 baris diambil sampai habis.
  Future<List<Map<String, dynamic>>> getAllTransactionsForExport({
    String query = '',
    String? statusFilter,
    String? locationId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return guardRequest(
      () => _fetchTransactions(
        query: query,
        statusFilter: statusFilter,
        locationId: locationId,
        startDate: startDate,
        endDate: endDate,
      ),
      // Ekspor bisa beberapa halaman; jangan putus di batas 20 detik.
      timeout: const Duration(seconds: 60),
    );
  }

  /// Query transaksi dengan filter server. `maxRows` null berarti tarik semua.
  Future<List<Map<String, dynamic>>> _fetchTransactions({
    required String query,
    String? statusFilter,
    String? locationId,
    DateTime? startDate,
    DateTime? endDate,
    int? maxRows,
  }) async {
    final rows = <Map<String, dynamic>>[];
    while (true) {
      var builder = _client.from('transactions').select(_selectWithRelations);
      if (statusFilter != null && statusFilter.isNotEmpty) {
        builder = builder.eq('status', statusFilter.toUpperCase());
      }
      if (locationId != null && locationId.isNotEmpty) {
        builder = builder.eq('location_id', locationId);
      }
      if (startDate != null) {
        builder = builder.gte(
          'created_at',
          startDate.toUtc().toIso8601String(),
        );
      }
      if (endDate != null) {
        builder = builder.lt('created_at', endDate.toUtc().toIso8601String());
      }

      final needle = _bersihkanCari(query);
      if (needle.isNotEmpty) {
        final pola = '%$needle%';
        builder = builder.or(
          'tx_code.ilike.$pola,'
          'profiles.full_name.ilike.$pola,'
          'profiles.nim.ilike.$pola',
        );
      }

      final sisa = maxRows == null ? _pageSize : maxRows - rows.length;
      final ambil = sisa < _pageSize ? sisa : _pageSize;
      if (ambil <= 0) break;

      // Urutan id sebagai penentu agar baris tidak terduplikasi antarhalaman.
      final res = await builder
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(rows.length, rows.length + ambil - 1);
      final batch = (res as List<dynamic>).cast<Map<String, dynamic>>();
      rows.addAll(batch);
      if (batch.length < ambil) break;
    }
    return rows;
  }

  /// Membuang karakter yang bermakna khusus di filter PostgREST.
  static String _bersihkanCari(String value) =>
      value.trim().replaceAll(RegExp(r'[,()*]'), ' ').trim();

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
