/// Model data pengajuan penarikan saldo mahasiswa.
class WithdrawalModel {
  final String id;
  final String mahasiswaId;
  final double amount;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final String? rejectionReason;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  /// Relasi opsional profiles (dipakai tampilan admin).
  final String? studentName;
  final String? studentNim;

  /// Token QR penarikan, dipakai admin saat memindai.
  final String? qrToken;

  const WithdrawalModel({
    required this.id,
    required this.mahasiswaId,
    required this.amount,
    required this.status,
    this.rejectionReason,
    this.verifiedAt,
    required this.createdAt,
    this.studentName,
    this.studentNim,
    this.qrToken,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  factory WithdrawalModel.fromJson(Map<String, dynamic> json) {
    // Relasi join bisa null / tidak ikut ter-select.
    final profile = json['profiles'];
    final profileMap = profile is Map ? profile : null;

    return WithdrawalModel(
      id: json['id'] as String,
      mahasiswaId: (json['mahasiswa_id'] as String?) ?? '',
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : 0.0,
      status: (json['status'] as String?) ?? 'PENDING',
      rejectionReason: json['rejection_reason'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      studentName: profileMap?['full_name'] as String?,
      studentNim: profileMap?['nim'] as String?,
      qrToken: json['qr_token'] as String?,
    );
  }
}
