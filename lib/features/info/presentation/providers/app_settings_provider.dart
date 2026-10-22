import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/app_settings_repository.dart';
import '../../domain/models/app_settings_model.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(supabase);
});

/// Pengaturan global; dibuang saat sesi berganti agar tidak bocor antar-akun.
final appSettingsProvider = FutureProvider<AppSettingsModel>((ref) async {
  ref.watch(sessionEpochProvider);
  return ref.watch(appSettingsRepositoryProvider).getSettings();
});
