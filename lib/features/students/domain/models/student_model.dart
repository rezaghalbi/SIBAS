/// Baris data mahasiswa untuk layar admin (baca saja).
class StudentModel {
  final String id;
  final String fullName;
  final String email;
  final String? nim;
  final String? phone;
  final double balance;
  final double totalWeight;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  const StudentModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.nim,
    this.phone,
    this.balance = 0,
    this.totalWeight = 0,
    this.createdAt,
    this.deletedAt,
  });

  bool get terhapus => deletedAt != null;

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    double angka(Object? value) => value is num ? value.toDouble() : 0;
    DateTime? waktu(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;

    return StudentModel(
      id: (json['id'] as String?) ?? '',
      fullName: (json['full_name'] as String?)?.trim().isNotEmpty == true
          ? (json['full_name'] as String).trim()
          : 'Pengguna SIBAS',
      email: (json['email'] as String?) ?? '',
      nim: _teks(json['nim']),
      phone: _teks(json['phone']),
      balance: angka(json['balance']),
      totalWeight: angka(json['total_weight']),
      createdAt: waktu(json['created_at']),
      deletedAt: waktu(json['deleted_at']),
    );
  }

  static String? _teks(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
