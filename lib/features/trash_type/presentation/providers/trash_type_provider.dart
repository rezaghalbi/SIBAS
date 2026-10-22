import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../deposit/presentation/providers/deposit_provider.dart';
import '../../data/trash_type_repository.dart';

final trashTypeRepositoryProvider = Provider<TrashTypeRepository>((ref) {
  return TrashTypeRepository(supabase);
});

/// Semua jenis sampah (aktif + nonaktif) untuk halaman admin.
final allTrashTypesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(trashTypeRepositoryProvider).getAll();
});

/// URL publik foto jenis sampah; null bila belum ada foto.
final fotoJenisSampahUrlProvider =
    Provider.family<String?, String?>((ref, imagePath) {
  if (imagePath == null || imagePath.isEmpty) return null;
  return ref.watch(trashTypeRepositoryProvider).urlFoto(imagePath);
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
    Uint8List? foto,
    String? fotoMime,
  }) {
    return _run(() async {
      await _repo.create(
        name: name,
        unit: unit,
        pricePerKg: pricePerKg,
        description: description,
        foto: foto,
        fotoMime: fotoMime,
      );
    });
  }

  Future<bool> update(
    String id, {
    required String name,
    required String unit,
    required double pricePerKg,
    String? description,
    Uint8List? foto,
    String? fotoMime,
    bool hapusFoto = false,
  }) {
    return _run(() => _repo.update(
          id,
          name: name,
          unit: unit,
          pricePerKg: pricePerKg,
          description: description,
          foto: foto,
          fotoMime: fotoMime,
          hapusFoto: hapusFoto,
        ));
  }

  /// Hasil: 'hapus' / 'nonaktif', atau null bila gagal.
  Future<String?> hapusAman(String id) async {
    state = const AsyncValue.loading();
    try {
      final mode = await _repo.hapusAman(id);
      state = const AsyncValue.data(null);
      _segar();
      return mode;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> toggleActive(String id, bool isActive) =>
      _run(() => _repo.setActive(id, isActive));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
      _segar();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Data jenis sampah berubah: segarkan daftar admin dan kategori setor.
  void _segar() {
    _ref.invalidate(allTrashTypesProvider);
    _ref.invalidate(wasteCategoriesProvider);
  }
}
