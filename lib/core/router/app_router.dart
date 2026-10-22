import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/deposit/presentation/screens/setor_screen.dart';
import '../../features/deposit/presentation/screens/qr_display_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/history/presentation/screens/admin_history_screen.dart';
import '../../features/verification/presentation/screens/admin_dashboard_screen.dart';
import '../../features/verification/presentation/screens/admin_scan_screen.dart';

/// Konfigurasi GoRouter resmi SIBAS lengkap dengan seluruh rute aplikasi
///
/// Router dibuat sekali. Perubahan status login dikirim lewat `ValueNotifier`
/// agar GoRouter tidak dibuat ulang (yang akan mereset riwayat navigasi).
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AsyncValue<UserModel?>>(
    ref.read(currentUserProvider),
  );

  ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, next) {
    authNotifier.value = next;
  });
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = authNotifier.value;
      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      // 1. Belum login
      if (user == null) {
        return (isLoggingIn || isRegistering) ? null : '/login';
      }

      // 2. Sudah login tapi berada di layar login/register
      if (isLoggingIn || isRegistering) {
        return user.isAdmin ? '/admin/dashboard' : '/dashboard';
      }

      // 3. Mahasiswa mencoba akses rute admin (/admin/*)
      if (state.matchedLocation.startsWith('/admin') && !user.isAdmin) {
        return '/dashboard';
      }

      // 4. Admin mencoba akses rute khusus mahasiswa (/dashboard, /setor, /qr, /history)
      if ((state.matchedLocation == '/dashboard' ||
              state.matchedLocation == '/setor' ||
              state.matchedLocation.startsWith('/qr') ||
              state.matchedLocation == '/history') &&
          user.isAdmin) {
        return '/admin/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Mahasiswa Routes
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/setor',
        builder: (context, state) => const SetorScreen(),
      ),
      GoRoute(
        path: '/qr/:id',
        builder: (context, state) {
          final txId = state.pathParameters['id'] ?? '';
          return QrDisplayScreen(transactionId: txId);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/scan',
        builder: (context, state) => const AdminScanScreen(),
      ),
      GoRoute(
        path: '/admin/history',
        builder: (context, state) => const AdminHistoryScreen(),
      ),
    ],
  );
});
