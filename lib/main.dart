import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/theme.dart';
import 'core/network/supabase_client.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DateFormat/NumberFormat locale 'id_ID' dipakai di banyak layar.
  await initializeDateFormatting('id_ID', null);

  // Membaca kredensial dari --dart-define
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Tanpa dart-define, Supabase.initialize('') gagal dan layar putih.
  if (url.isEmpty || anonKey.isEmpty) {
    runApp(const _ConfigErrorApp());
    return;
  }

  // Wajib di-await sebelum runApp
  await AppSupabase.initialize(
    url: url,
    anonKey: anonKey,
  );

  runApp(
    const ProviderScope(
      child: SibasApp(),
    ),
  );
}

class SibasApp extends ConsumerWidget {
  const SibasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SIBAS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}

/// Ditampilkan bila build berjalan tanpa --dart-define SUPABASE_URL/ANON_KEY.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.error_outline, size: 48),
                SizedBox(height: 16),
                Text(
                  'Konfigurasi Supabase belum diisi.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Build ulang dengan --dart-define=SUPABASE_URL=... '
                  'dan --dart-define=SUPABASE_ANON_KEY=...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
