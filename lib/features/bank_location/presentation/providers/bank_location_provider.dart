import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/bank_location_repository.dart';
import '../../domain/models/bank_location_model.dart';

final bankLocationRepositoryProvider = Provider<BankLocationRepository>((ref) {
  return BankLocationRepository(supabase);
});

/// Daftar lokasi sesuai hak akses pengguna.
final bankLocationsProvider = FutureProvider<List<BankLocationModel>>((ref) {
  // Cache dibuang saat sesi berganti agar hak akses tidak bocor.
  ref.watch(sessionEpochProvider);
  return ref.watch(bankLocationRepositoryProvider).getLocations();
});

/// Turunan lokasi aktif untuk pemilih di layar setor/tarik.
/// Status loading/error dibaca dari [bankLocationsProvider].
final activeLocationsProvider = Provider<List<BankLocationModel>>((ref) {
  final semua = ref.watch(bankLocationsProvider).valueOrNull;
  if (semua == null) return const [];
  return semua.where((lokasi) => lokasi.isActive).toList(growable: false);
});

/// Lokasi terpilih pada alur setor/tarik. Sengaja di memori saja; belum
/// dipersist karena pilihan berlaku per pengajuan.
final selectedLocationProvider =
    StateProvider<BankLocationModel?>((ref) => null);
