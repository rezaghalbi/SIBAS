import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/features/history/domain/models/admin_history_filter.dart';

void main() {
  test('rentang hari ini dimulai pukul 00.00 lokal', () {
    final rentang = AdminHistoryFilter.rentangHari(
      1,
      now: DateTime(2026, 10, 28, 15, 30),
    );
    expect(rentang.start, DateTime(2026, 10, 28));
    expect(rentang.end, DateTime(2026, 10, 29));
  });

  test('tujuh hari mencakup hari ini dan enam hari sebelumnya', () {
    final rentang = AdminHistoryFilter.rentangHari(
      7,
      now: DateTime(2026, 10, 28, 0, 5),
    );
    expect(rentang.start, DateTime(2026, 10, 22));
    expect(rentang.end, DateTime(2026, 10, 29));
  });

  test('copyWith membersihkan status dan tanggal tanpa menyentuh query', () {
    final filter = AdminHistoryFilter(
      query: 'ani',
      status: 'APPROVED',
      startDate: DateTime(2026, 10, 22),
      endDate: DateTime(2026, 10, 29),
    );
    final bersih = filter.copyWith(clearStatus: true, clearDates: true);
    expect(bersih.query, 'ani');
    expect(bersih.status, isNull);
    expect(bersih.hasDateFilter, isFalse);
  });
}
