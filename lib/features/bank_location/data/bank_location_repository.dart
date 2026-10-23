import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_guard.dart';
import '../domain/models/bank_location_model.dart';

/// Repository master lokasi bank sampah (baca untuk semua, tulis untuk admin).
class BankLocationRepository {
  final SupabaseClient _client;

  BankLocationRepository(this._client);

  /// Semua lokasi yang boleh dilihat pengguna. Mahasiswa hanya menerima
  /// lokasi aktif; admin menerima semuanya (diatur RLS + RPC).
  Future<List<BankLocationModel>> getLocations() {
    return guardRequest(() async {
      final res = await _client.rpc('get_locations');
      if (res is List) {
        return res
            .cast<Map<String, dynamic>>()
            .map(BankLocationModel.fromJson)
            .toList();
      }
      return const [];
    });
  }

  /// Simpan lokasi baru (`id` null) atau perbarui lokasi yang ada.
  /// Seluruh nama parameter selalu dikirim agar tidak ada overload ambigu.
  Future<BankLocationModel> simpan({
    String? id,
    required String name,
    required String address,
    double? latitude,
    double? longitude,
    bool isActive = true,
  }) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'simpan_lokasi',
        params: {
          'p_id': id,
          'p_name': name,
          'p_address': address,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_is_active': isActive,
        },
      );
      final map =
          res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      return BankLocationModel.fromJson(map);
    });
  }

  /// Hapus permanen bila belum dipakai transaksi. Server membalas
  /// `{'dihapus': false}` bila lokasi hanya dinonaktifkan.
  Future<bool> hapus(String id) {
    return guardRequest(() async {
      final res = await _client.rpc('hapus_lokasi', params: {'p_id': id});
      final map =
          res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      return map['dihapus'] == true;
    });
  }
}
