import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../verification/presentation/providers/verification_provider.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../../domain/models/admin_history_filter.dart';

/// Filter khusus layar Riwayat admin (pencarian, status, tanggal).
final adminHistoryFilterProvider =
    StateProvider<AdminHistoryFilter>((ref) => const AdminHistoryFilter());

/// Daftar setoran layar Riwayat.
///
/// Filter dikirim ke server agar hasil tidak terpotong oleh baris yang sudah
/// dimuat. Filter lokasi tetap mengikuti pilihan admin di dashboard.
final adminHistoryTransactionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(verificationRepositoryProvider);
  final filter = ref.watch(adminHistoryFilterProvider);
  final locationId = ref.watch(adminFilterProvider).locationId;
  // Cache dibuang saat sesi berganti (logout/login akun lain).
  ref.watch(sessionEpochProvider);
  return repo.getAllTransactions(
    query: filter.query,
    statusFilter: filter.status,
    locationId: locationId,
    startDate: filter.startDate,
    endDate: filter.endDate,
    limit: ref.watch(adminPageLimitProvider),
  );
});

/// Daftar penarikan untuk tab Riwayat admin. Memakai filter tanggal/status
/// yang sama dengan setoran agar tab tetap konsisten.
final adminHistoryWithdrawalsProvider =
    FutureProvider<List<WithdrawalModel>>((ref) async {
  final repo = ref.watch(withdrawalRepositoryProvider);
  final filter = ref.watch(adminHistoryFilterProvider);
  final locationId = ref.watch(adminFilterProvider).locationId;
  ref.watch(sessionEpochProvider);
  return repo.getAllWithdrawals(
    statusFilter: filter.status,
    locationId: locationId,
    query: filter.query,
    startDate: filter.startDate,
    endDate: filter.endDate,
    limit: ref.watch(adminPageLimitProvider),
  );
});
