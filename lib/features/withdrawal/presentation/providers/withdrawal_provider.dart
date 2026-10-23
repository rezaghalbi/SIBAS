import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../verification/presentation/providers/verification_provider.dart';
import '../../data/withdrawal_repository.dart';
import '../../domain/models/withdrawal_model.dart';

final withdrawalRepositoryProvider = Provider<WithdrawalRepository>((ref) {
  return WithdrawalRepository(supabase);
});

/// Saldo yang bisa ditarik milik pengguna aktif.
final availableBalanceProvider = FutureProvider<double>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return 0.0;

  final repo = ref.watch(withdrawalRepositoryProvider);
  return repo.getAvailableBalance(user.id);
});

/// Riwayat penarikan mahasiswa yang sedang login.
final studentWithdrawalsProvider =
    FutureProvider<List<WithdrawalModel>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];

  final repo = ref.watch(withdrawalRepositoryProvider);
  return repo.getStudentWithdrawals(user.id);
});

/// Daftar penarikan untuk admin. Argumen = filter status (null = semua).
/// Pencarian, lokasi, dan batas baris mengikuti provider yang sama dengan
/// daftar setoran agar paginasi konsisten.
final adminWithdrawalsProvider =
    FutureProvider.family<List<WithdrawalModel>, String?>((ref, status) async {
  final repo = ref.watch(withdrawalRepositoryProvider);
  final filter = ref.watch(adminFilterProvider);
  // Cache admin dibuang saat sesi berganti.
  ref.watch(sessionEpochProvider);
  return repo.getAllWithdrawals(
    statusFilter: status,
    locationId: filter.locationId,
    query: filter.query,
    limit: ref.watch(adminPageLimitProvider),
  );
});

/// Detail penarikan dari RPC server: nama pengaju, admin penyetuju, dan audit.
final withdrawalDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  if (id.isEmpty) return null;
  ref.watch(sessionEpochProvider);
  final data = await supabase.rpc('detail_penarikan', params: {'p_id': id});
  return data as Map<String, dynamic>?;
});

/// Aksi tulis penarikan. State berisi error terakhir untuk snackbar/form.
final withdrawalControllerProvider =
    StateNotifierProvider<WithdrawalController, AsyncValue<void>>((ref) {
  return WithdrawalController(ref);
});

class WithdrawalController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  WithdrawalController(this._ref) : super(const AsyncValue.data(null));

  WithdrawalRepository get _repo => _ref.read(withdrawalRepositoryProvider);

  Future<WithdrawalModel?> create(double amount, {String? locationId}) async {
    state = const AsyncValue.loading();
    try {
      final created = await _repo.createWithdrawal(
        amount,
        locationId: locationId,
      );
      state = const AsyncValue.data(null);
      _refresh();
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> approve(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.approveWithdrawal(id);
      state = const AsyncValue.data(null);
      _refresh();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> reject(String id, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _repo.rejectWithdrawal(id, reason);
      state = const AsyncValue.data(null);
      _refresh();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Setujui lewat token QR hasil pindai (khusus admin).
  Future<bool> approveByQr(String token) async {
    state = const AsyncValue.loading();
    try {
      await _repo.approveWithdrawalByQr(token);
      state = const AsyncValue.data(null);
      _refresh();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Saldo ikut berubah setelah pengajuan/verifikasi admin.
  void _refresh() {
    _ref.invalidate(availableBalanceProvider);
    _ref.invalidate(studentWithdrawalsProvider);
    _ref.invalidate(adminWithdrawalsProvider);
    // Detail ikut dibuang agar audit/nama verifikator tidak basi.
    _ref.invalidate(withdrawalDetailProvider);
    _ref.invalidate(currentUserProvider);
  }
}
