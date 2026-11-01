/// Filter layar Riwayat admin: pencarian, status, dan rentang tanggal.
///
/// Dipisah dari `AdminTransactionFilter` agar filter tanggal layar Riwayat
/// tidak mengubah daftar pada layar Pengajuan.
class AdminHistoryFilter {
  final String query;
  final String? status;

  /// Batas bawah inklusif dan batas atas eksklusif dalam waktu lokal.
  final DateTime? startDate;
  final DateTime? endDate;

  const AdminHistoryFilter({
    this.query = '',
    this.status,
    this.startDate,
    this.endDate,
  });

  bool get hasDateFilter => startDate != null || endDate != null;

  AdminHistoryFilter copyWith({
    String? query,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStatus = false,
    bool clearDates = false,
  }) {
    return AdminHistoryFilter(
      query: query ?? this.query,
      status: clearStatus ? null : (status ?? this.status),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
    );
  }

  /// Rentang hari kalender lokal untuk chip tanggal.
  ///
  /// `days = 1` berarti sejak pukul 00.00 hari ini, `days = 7` berarti tujuh
  /// hari kalender terakhir termasuk hari ini. Batas atas eksklusif agar
  /// query memakai `created_at < end`. Aritmetika tanggal (bukan durasi)
  /// dipakai supaya tetap benar saat zona waktu punya pergantian DST.
  static ({DateTime start, DateTime end}) rentangHari(
    int days, {
    DateTime? now,
  }) {
    final acuan = now ?? DateTime.now();
    return (
      start: DateTime(acuan.year, acuan.month, acuan.day - (days - 1)),
      end: DateTime(acuan.year, acuan.month, acuan.day + 1),
    );
  }
}
