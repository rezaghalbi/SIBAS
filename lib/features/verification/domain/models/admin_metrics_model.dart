/// Rekap satu lokasi bank sampah pada Dashboard Admin.
class LocationMetric {
  final String id;
  final String name;
  final bool isActive;
  final double totalWeightKg;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;

  const LocationMetric({
    required this.id,
    required this.name,
    required this.isActive,
    required this.totalWeightKg,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
  });

  factory LocationMetric.fromJson(Map<String, dynamic> json) {
    double asDouble(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? 0;
    }

    int asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return LocationMetric(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      totalWeightKg: asDouble(json['total_weight_kg']),
      pendingCount: asInt(json['pending_count']),
      approvedCount: asInt(json['approved_count']),
      rejectedCount: asInt(json['rejected_count']),
    );
  }
}

/// Model metrik statistik untuk Dashboard Admin
class AdminMetricsModel {
  final double totalWeightKg;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;

  /// Lokasi yang sedang difilter; null berarti semua lokasi.
  final String? locationId;

  /// Rekap setiap lokasi, urut nama.
  final List<LocationMetric> locations;

  const AdminMetricsModel({
    required this.totalWeightKg,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    this.locationId,
    this.locations = const [],
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

  /// Filter lokasi bank sampah; null berarti semua lokasi.
  final String? locationId;

  const AdminTransactionFilter({
    this.query = '',
    this.status,
    this.startDate,
    this.endDate,
    this.locationId,
  });

  AdminTransactionFilter copyWith({
    String? query,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? locationId,
    bool clearStatus = false,
    bool clearLocation = false,
  }) {
    return AdminTransactionFilter(
      query: query ?? this.query,
      status: clearStatus ? null : (status ?? this.status),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      locationId: clearLocation ? null : (locationId ?? this.locationId),
    );
  }
}
