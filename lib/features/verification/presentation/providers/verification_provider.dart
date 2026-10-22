import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/verification_repository.dart';
import '../../domain/models/admin_metrics_model.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return VerificationRepository(supabase);
});

/// Provider metrik admin
final adminMetricsProvider = FutureProvider<AdminMetricsModel>((ref) async {
  final repo = ref.watch(verificationRepositoryProvider);
  // Ikut dibuang saat sesi berganti (logout/login akun lain).
  ref.watch(sessionEpochProvider);
  return repo.getAdminMetrics();
});

/// State filter transaksi admin
final adminFilterProvider = StateProvider<AdminTransactionFilter>((ref) {
  return const AdminTransactionFilter();
});

/// Provider daftar transaksi admin dengan filter
final adminTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(verificationRepositoryProvider);
  final filter = ref.watch(adminFilterProvider);
  // Ikut dibuang saat sesi berganti.
  ref.watch(sessionEpochProvider);
  return repo.getAllTransactions(
    query: filter.query,
    statusFilter: filter.status,
  );
});
