/// Model data transaksi penyetoran sampah SIBAS
class TransactionModel {
  final String id;
  final String userId;
  final String? categoryId;
  final String categoryName;
  final double weight; // Berat manual kg
  final double? estimatedAmount;
  final double? finalAmount;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED', 'EXPIRED'
  final String? rejectionReason;
  final String? adminId;
  final String? qrToken;
  final String? txCode;

  /// Lokasi bank sampah tempat setoran diajukan. Null untuk data lama yang
  /// belum punya relasi lokasi.
  final String? locationId;
  final String? locationName;

  final DateTime createdAt;
  final DateTime? qrExpiresAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.categoryName,
    required this.weight,
    this.estimatedAmount,
    this.finalAmount,
    required this.status,
    this.rejectionReason,
    this.adminId,
    this.qrToken,
    this.txCode,
    this.locationId,
    this.locationName,
    required this.createdAt,
    this.qrExpiresAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Menangani relasi join kategori jika ada
    String catName = 'Sampah Daur Ulang';
    if (json['trash_types'] != null && json['trash_types'] is Map) {
      catName = (json['trash_types']['name'] as String?) ?? catName;
    } else if (json['category_name'] != null) {
      catName = json['category_name'] as String;
    }

    // Relasi lokasi hanya ada pada respons RPC (insert/detail), bisa null.
    final lokasi = json['location'];
    final lokasiMap = lokasi is Map ? lokasi : null;

    return TransactionModel(
      id: json['id'] as String,
      userId: (json['mahasiswa_id'] as String?) ?? '',
      categoryId: json['trash_type_id'] as String?,
      categoryName: catName,
      weight: (json['weight'] != null) ? (json['weight'] as num).toDouble() : 0.0,
      estimatedAmount: json['estimated_amount'] != null
          ? (json['estimated_amount'] as num).toDouble()
          : null,
      finalAmount: json['final_amount'] != null
          ? (json['final_amount'] as num).toDouble()
          : null,
      status: (json['status'] as String?) ?? 'PENDING',
      rejectionReason: json['rejection_reason'] as String?,
      adminId: json['verified_by'] as String?,
      qrToken: json['qr_token'] as String?,
      txCode: json['tx_code'] as String?,
      locationId: json['location_id'] as String?,
      locationName: lokasiMap?['name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      qrExpiresAt: json['qr_expires_at'] != null
          ? DateTime.tryParse(json['qr_expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mahasiswa_id': userId,
      'trash_type_id': categoryId,
      'weight': weight,
      'estimated_amount': estimatedAmount,
      'final_amount': finalAmount,
      'status': status,
      'rejection_reason': rejectionReason,
      'admin_id': adminId,
      'location_id': locationId,
      'created_at': createdAt.toIso8601String(),
      'qr_expires_at': qrExpiresAt?.toIso8601String(),
    };
  }
}
