/// Model metrik statistik untuk Dashboard Admin
class AdminMetricsModel {
  final double totalWeightKg;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;

  const AdminMetricsModel({
    required this.totalWeightKg,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
  });

  factory AdminMetricsModel.empty() {
    return const AdminMetricsModel(
      totalWeightKg: 0.0,
      pendingCount: 0,
      approvedCount: 0,
      rejectedCount: 0,
    );
  }
}

/// Kriteria filter & pencarian transaksi Admin sesuai contracts.md & prd.md
class AdminTransactionFilter {
  final String query; // Pencarian Nama Mahasiswa atau NIM
  final String? status; // 'Menunggu Verifikasi', 'Disetujui', 'Ditolak', 'Kedaluwarsa'
  final DateTime? startDate;
  final DateTime? endDate;

  const AdminTransactionFilter({
    this.query = '',
    this.status,
    this.startDate,
    this.endDate,
  });

  AdminTransactionFilter copyWith({
    String? query,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStatus = false,
  }) {
    return AdminTransactionFilter(
      query: query ?? this.query,
      status: clearStatus ? null : (status ?? this.status),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}
