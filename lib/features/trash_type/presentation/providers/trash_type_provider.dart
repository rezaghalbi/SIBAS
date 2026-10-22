import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/trash_type_repository.dart';

final trashTypeRepositoryProvider = Provider<TrashTypeRepository>((ref) {
  return TrashTypeRepository(supabase);
});

/// Semua jenis sampah (aktif + nonaktif) untuk halaman admin.
final allTrashTypesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(trashTypeRepositoryProvider).getAll();
});

/// Aksi tulis master data. State berisi error terakhir untuk snackbar/form.
final trashTypeControllerProvider =
    StateNotifierProvider<TrashTypeController, AsyncValue<void>>((ref) {
  return TrashTypeController(ref);
});

class TrashTypeController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  TrashTypeController(this._ref) : super(const AsyncValue.data(null));

  TrashTypeRepository get _repo => _ref.read(trashTypeRepositoryProvider);

  Future<bool> create({
    required String name,
    required String unit,
    required double pricePerKg,
    String? description,
  }) {
    return _run(() async {
      await _repo.create(
        name: name,
        unit: unit,
        pricePerKg: pricePerKg,
        description: description,
      );
    });
  }

  Future<bool> update(
    String id, {
    required String name,
    required String unit,
    required double pricePerKg,
    String? description,
  }) {
    return _run(() => _repo.update(
          id,
          name: name,
          unit: unit,
          pricePerKg: pricePerKg,
          description: description,
        ));
  }

  Future<bool> delete(String id) => _run(() => _repo.delete(id));

  Future<bool> toggleActive(String id, bool isActive) =>
      _run(() => _repo.setActive(id, isActive));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      _ref.invalidate(allTrashTypesProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
