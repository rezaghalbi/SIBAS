/// Model data profil pengguna SIBAS
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? nim;
  final String role; // 'mahasiswa' atau 'admin'
  final double balance;
  final double totalWeight;
  final DateTime? createdAt;

  /// Waktu akun ditandai terhapus (soft delete). Non-null berarti akun tidak
  /// boleh dipakai lagi.
  final DateTime? deletedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.nim,
    required this.role,
    this.balance = 0.0,
    this.totalWeight = 0.0,
    this.createdAt,
    this.deletedAt,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isMahasiswa => role.toLowerCase() == 'mahasiswa';

  factory UserModel.fromJson(Map<String, dynamic> json, {String? emailFallback}) {
    return UserModel(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? emailFallback ?? '',
      fullName: (json['full_name'] as String?) ?? 'Pengguna SIBAS',
      nim: json['nim'] as String?,
      role: (json['role'] as String?) ?? 'mahasiswa',
      balance: (json['balance'] != null) ? (json['balance'] as num).toDouble() : 0.0,
      totalWeight: (json['total_weight'] != null) ? (json['total_weight'] as num).toDouble() : 0.0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'nim': nim,
      'role': role,
      'balance': balance,
      'total_weight': totalWeight,
      'created_at': createdAt?.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
    };
  }
}
