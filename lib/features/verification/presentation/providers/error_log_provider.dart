import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Log error klien terbaru untuk admin. RLS hanya mengizinkan admin membaca.
final errorLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(sessionEpochProvider);
  final res = await supabase
      .from('client_error_logs')
      .select('id, pesan, detail, platform, versi_aplikasi, dibuat_pada')
      .order('dibuat_pada', ascending: false)
      .limit(100);
  return (res as List<dynamic>).cast<Map<String, dynamic>>();
});
