import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/colors.dart';
import 'core/constants/theme.dart';
import 'core/network/error_reporter.dart';
import 'core/network/supabase_client.dart';
import 'core/widgets/session_idle_watcher.dart';
import 'core/router/app_router.dart';
import 'core/widgets/offline_banner.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Jangan biarkan exception tak tertangkap menghasilkan layar putih.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    unawaited(laporkanKesalahan(
      details.exception,
      details.stack,
      konteks: 'FlutterError',
    ));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error');
    unawaited(laporkanKesalahan(error, stack, konteks: 'platform'));
    return true;
  };
  ErrorWidget.builder = (details) => const Material(
        color: AppColors.background,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Terjadi kesalahan pada tampilan. Muat ulang halaman ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
          ),
        ),
      );

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

  // Tautan pemulihan sandi (PKCE) mendarat di path /reset-password tanpa hash.
  // Disimpan sebelum router dibuat agar redirect pemulihan tidak bergantung
  // pada event auth yang hanya signedIn.
  final mulaiPemulihan = kIsWeb &&
      Uri.base.path.endsWith('/reset-password') &&
      !Uri.base.fragment.startsWith('/');

  runApp(
    ProviderScope(
      overrides: [
        awalPemulihanSandiProvider.overrideWithValue(mulaiPemulihan),
      ],
      child: const SibasApp(),
    ),
  );
}

class SibasApp extends ConsumerWidget {
  const SibasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return MaterialApp.router(
      title: 'SIBAS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Layar masih membaca AppColors hardcoded, jadi mode gelap belum utuh.
      // Tema gelap disiapkan, tetapi baru dipasang ke sistem pada tahap 5
      // (docs/DESIGN_SYSTEM_V2.md §11).
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) => Column(
        children: [
          const OfflineBanner(),
          Expanded(
            // Sesi yang didiamkan 30 menit diakhiri, bukan dibiarkan terbuka.
            child: SessionIdleWatcher(
              aktif: user != null,
              saatIdle: () => ref.read(currentUserProvider.notifier).logout(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
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
