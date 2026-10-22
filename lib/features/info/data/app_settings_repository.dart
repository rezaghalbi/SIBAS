import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_guard.dart';
import '../domain/models/app_settings_model.dart';

/// Baca/simpan pengaturan global lewat RPC (bukan update tabel langsung).
class AppSettingsRepository {
  final SupabaseClient _client;

  AppSettingsRepository(this._client);

  Future<AppSettingsModel> getSettings() {
    return guardRequest(() async {
      final res = await _client.rpc('get_app_settings');
      final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      return AppSettingsModel.fromJson(map);
    });
  }

  Future<AppSettingsModel> updateSettings({
    required int qrTtlMinutes,
    String? contactEmail,
    String? contactLocation,
    String? contactHours,
  }) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'update_app_settings',
        params: {
          'p_qr_ttl_minutes': qrTtlMinutes,
          'p_contact_email': contactEmail,
          'p_contact_location': contactLocation,
          'p_contact_hours': contactHours,
        },
      );
      final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      return AppSettingsModel.fromJson(map);
    });
  }
}
