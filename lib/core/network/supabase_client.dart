import 'package:supabase_flutter/supabase_flutter.dart';

/// Inisialisasi Supabase Client resmi
/// Konfigurasi URL dan Anon Key disiapkan secara terpusat
class AppSupabase {
  AppSupabase._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

/// Shortcut getter klien supabase sesuai contracts.md
final supabase = Supabase.instance.client;
