import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/api_guard.dart';

/// Repository master data jenis sampah (khusus admin).
/// Baris dikembalikan sebagai Map agar tidak menambah model baru.
class TrashTypeRepository {
  final SupabaseClient _client;

  TrashTypeRepository(this._client);

  static const _uniqueNameMessage = 'Nama jenis sampah sudah ada.';
  static const _bucket = 'trash-type-images';

  /// Semua jenis sampah termasuk yang nonaktif.
  Future<List<Map<String, dynamic>>> getAll() {
    return guardRequest(() async {
      final res = await _client
          .from('trash_types')
          .select('*')
          .order('name', ascending: true);
      return (res as List<dynamic>).cast<Map<String, dynamic>>();
    });
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required String unit,
    required double pricePerKg,
    String? description,
    Uint8List? foto,
    String? fotoMime,
  }) {
    return guardRequest(() async {
      try {
        final res = await _client
            .from('trash_types')
            .insert({
              'name': name.trim(),
              'unit': unit.trim(),
              'price_per_kg': pricePerKg,
              'description': description?.trim(),
            })
            .select('*')
            .single();
        await _simpanFoto(res['id'] as String, null, foto, fotoMime, false);
        return res;
      } on PostgrestException catch (e) {
        throw Exception(
          e.code == '23505' ? _uniqueNameMessage : e.message,
        );
      }
    });
  }

  Future<void> update(
    String id, {
    required String name,
    required String unit,
    required double pricePerKg,
    String? description,
    Uint8List? foto,
    String? fotoMime,
    bool hapusFoto = false,
  }) {
    return guardRequest(() async {
      try {
        final res = await _client
            .from('trash_types')
            .update({
              'name': name.trim(),
              'unit': unit.trim(),
              'price_per_kg': pricePerKg,
              'description': description?.trim(),
            })
            .eq('id', id)
            .select('image_path')
            .maybeSingle();
        await _simpanFoto(
          id,
          res?['image_path'] as String?,
          foto,
          fotoMime,
          hapusFoto,
        );
      } on PostgrestException catch (e) {
        throw Exception(
          e.code == '23505' ? _uniqueNameMessage : e.message,
        );
      }
    });
  }

  /// Hapus permanen bila belum dipakai transaksi, selain itu nonaktifkan.
  /// Mengembalikan mode: 'hapus' atau 'nonaktif'.
  Future<String> hapusAman(String id) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'hapus_jenis_sampah',
        params: {'p_id': id},
      );
      final map = (res as Map).cast<String, dynamic>();
      return (map['mode'] as String?) ?? 'hapus';
    });
  }

  Future<void> setActive(String id, bool isActive) {
    return guardRequest(() async {
      await _client
          .from('trash_types')
          .update({'is_active': isActive}).eq('id', id);
    });
  }

  /// URL publik foto jenis sampah.
  String urlFoto(String path) =>
      _client.storage.from(_bucket).getPublicUrl(path);

  /// Unggah/ganti/hapus foto setelah baris tersimpan.
  Future<void> _simpanFoto(
    String id,
    String? lama,
    Uint8List? foto,
    String? mime,
    bool hapusFoto,
  ) async {
    if (foto != null && foto.isNotEmpty) {
      final path =
          '$id/foto-${DateTime.now().millisecondsSinceEpoch}.${_ext(mime)}';
      await _client.storage.from(_bucket).uploadBinary(
            path,
            foto,
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );
      await _client
          .from('trash_types')
          .update({'image_path': path}).eq('id', id);
      if (lama != null && lama.isNotEmpty && lama != path) {
        // Objek lama gagal dihapus tidak boleh menggagalkan simpan.
        try {
          await _client.storage.from(_bucket).remove([lama]);
        } catch (_) {}
      }
    } else if (hapusFoto) {
      if (lama != null && lama.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove([lama]);
        } catch (_) {}
      }
      await _client
          .from('trash_types')
          .update({'image_path': null}).eq('id', id);
    }
  }

  String _ext(String? mime) {
    final m = mime?.toLowerCase() ?? '';
    if (m.contains('png')) return 'png';
    if (m.contains('webp')) return 'webp';
    return 'jpg';
  }
}
