import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/verification_repository.dart';
import '../../domain/models/admin_metrics_model.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return VerificationRepository(supabase);
});

/// Jumlah baris yang diminta daftar admin. Naik saat "Muat lebih banyak".
final adminPageLimitProvider = StateProvider<int>((ref) => 50);

enum AdminMetricsPeriod { all, month }

/// Periode ringkasan dashboard admin.
final adminMetricsPeriodProvider =
    StateProvider<AdminMetricsPeriod>((ref) => AdminMetricsPeriod.all);

/// Provider metrik admin, mengikuti filter lokasi dan periode aktif.
final adminMetricsProvider = FutureProvider<AdminMetricsModel>((ref) async {
  final repo = ref.watch(verificationRepositoryProvider);
  final lokasi = ref.watch(adminFilterProvider).locationId;
  final periode = ref.watch(adminMetricsPeriodProvider);
  // Ikut dibuang saat sesi berganti (logout/login akun lain).
  ref.watch(sessionEpochProvider);

  DateTime? mulai;
  DateTime? selesai;
  if (periode == AdminMetricsPeriod.month) {
    final now = DateTime.now();
    mulai = DateTime(now.year, now.month);
    selesai = DateTime(now.year, now.month + 1);
  }

  return repo.getAdminMetrics(
    locationId: lokasi,
    startDate: mulai,
    endDate: selesai,
  );
});

/// State filter transaksi admin
final adminFilterProvider = StateProvider<AdminTransactionFilter>((ref) {
  return const AdminTransactionFilter();
});

/// Antrean setoran yang belum diverifikasi. Dipakai layar Pengajuan agar
/// tidak menampilkan arsip status lain.
final adminPendingTransactionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(verificationRepositoryProvider);
  final filter = ref.watch(adminFilterProvider);
  ref.watch(sessionEpochProvider);
  return repo.getAllTransactions(
    query: filter.query,
    statusFilter: 'PENDING',
    locationId: filter.locationId,
    limit: ref.watch(adminPageLimitProvider),
  );
});

/// Lima transaksi terbaru untuk ringkasan dashboard admin.
final adminRecentTransactionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(verificationRepositoryProvider);
  final filter = ref.watch(adminFilterProvider);
  ref.watch(sessionEpochProvider);
  return repo.getAllTransactions(
    locationId: filter.locationId,
    limit: 5,
  );
});
