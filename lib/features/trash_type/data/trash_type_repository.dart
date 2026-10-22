import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/api_guard.dart';

/// Repository master data jenis sampah (khusus admin).
/// Baris dikembalikan sebagai Map agar tidak menambah model baru.
class TrashTypeRepository {
  final SupabaseClient _client;

  TrashTypeRepository(this._client);

  static const _uniqueNameMessage = 'Nama jenis sampah sudah ada.';

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
  }) {
    return guardRequest(() async {
      try {
        await _client.from('trash_types').update({
          'name': name.trim(),
          'unit': unit.trim(),
          'price_per_kg': pricePerKg,
          'description': description?.trim(),
        }).eq('id', id);
      } on PostgrestException catch (e) {
        throw Exception(
          e.code == '23505' ? _uniqueNameMessage : e.message,
        );
      }
    });
  }

  Future<void> delete(String id) {
    return guardRequest(() async {
      await _client.from('trash_types').delete().eq('id', id);
    });
  }

  Future<void> setActive(String id, bool isActive) {
    return guardRequest(() async {
      await _client
          .from('trash_types')
          .update({'is_active': isActive}).eq('id', id);
    });
  }
}
