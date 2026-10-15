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
  final DateTime createdAt;
  final DateTime? expiresAt;

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
    required this.createdAt,
    this.expiresAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Menangani relasi join kategori jika ada
    String catName = 'Sampah Daur Ulang';
    if (json['waste_categories'] != null && json['waste_categories'] is Map) {
      catName = (json['waste_categories']['name'] as String?) ?? catName;
    } else if (json['category_name'] != null) {
      catName = json['category_name'] as String;
    }

    return TransactionModel(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      categoryId: json['category_id'] as String?,
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
      adminId: json['admin_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'weight': weight,
      'estimated_amount': estimatedAmount,
      'final_amount': finalAmount,
      'status': status,
      'rejection_reason': rejectionReason,
      'admin_id': adminId,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}
