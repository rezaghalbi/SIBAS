import 'package:supabase_flutter/supabase_flutter.dart';

/// Inisialisasi Supabase Client resmi
/// Konfigurasi URL dan Anon Key disiapkan secara terpusat
class AppSupabase {
  AppSupabase._();

  static SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      throw StateError('SupabaseClient diakses sebelum AppSupabase.initialize() selesai.');
    }
  }

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

/// Shortcut getter klien supabase yang aman dari LateInitializationError
SupabaseClient get supabase => Supabase.instance.client;