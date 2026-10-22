import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/deposit/presentation/screens/qr_display_screen.dart';
import '../../features/deposit/presentation/screens/setor_screen.dart';
import '../../features/history/presentation/screens/admin_history_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/history/presentation/screens/transaction_detail_screen.dart';
import '../../features/info/presentation/screens/info_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/saldo/presentation/screens/saldo_screen.dart';
import '../../features/trash_type/presentation/screens/trash_type_management_screen.dart';
import '../../features/verification/presentation/providers/verification_provider.dart';
import '../../features/verification/presentation/screens/admin_dashboard_screen.dart';
import '../../features/verification/presentation/screens/admin_scan_screen.dart';
import '../../features/verification/presentation/screens/admin_submissions_screen.dart';
import '../widgets/app_bottom_nav.dart';

/// Konfigurasi GoRouter resmi SIBAS lengkap dengan seluruh rute aplikasi.
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
      final location = state.matchedLocation;
      final isLoggingIn = location == '/login';
      final isRegistering = location == '/register';

      // 1. Belum login
      if (user == null) {
        return (isLoggingIn || isRegistering) ? null : '/login';
      }

      // 2. Sudah login tapi berada di layar login/register
      if (isLoggingIn || isRegistering) {
        return user.isAdmin ? '/admin/dashboard' : '/dashboard';
      }

      // 3. Mahasiswa mencoba akses rute admin (/admin/*)
      if (location.startsWith('/admin') && !user.isAdmin) {
        return '/dashboard';
      }

      // 4. Admin mencoba akses rute khusus mahasiswa
      const ruteMahasiswa = ['/dashboard', '/setor', '/history', '/saldo', '/profile', '/info'];
      final isRuteMahasiswa = ruteMahasiswa.contains(location) ||
          location.startsWith('/qr') ||
          location.startsWith('/transaction');
      if (isRuteMahasiswa && user.isAdmin) {
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

      // Mahasiswa — memakai bottom nav
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const _NavScaffold(index: 0, child: DashboardScreen()),
      ),
      GoRoute(
        path: '/setor',
        builder: (context, state) => const _NavScaffold(index: 1, child: SetorScreen()),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const _NavScaffold(index: 2, child: HistoryScreen()),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const _NavScaffold(index: 3, child: ProfileScreen()),
      ),

      // Rute pendukung mahasiswa tanpa bottom nav
      GoRoute(
        path: '/qr/:id',
        builder: (context, state) {
          final txId = state.pathParameters['id'] ?? '';
          return QrDisplayScreen(transactionId: txId);
        },
      ),
      GoRoute(
        path: '/saldo',
        builder: (context, state) => const SaldoScreen(),
      ),
      GoRoute(
        path: '/info',
        builder: (context, state) => const InfoScreen(),
      ),
      GoRoute(
        path: '/transaction/:id',
        builder: (context, state) {
          final txId = state.pathParameters['id'] ?? '';
          return TransactionDetailScreen(transactionId: txId);
        },
      ),

      // Admin — memakai bottom nav
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const _NavScaffold(index: 0, child: AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/admin/submissions',
        builder: (context, state) => const _NavScaffold(index: 1, child: AdminSubmissionsScreen()),
      ),
      GoRoute(
        path: '/admin/scan',
        builder: (context, state) => const _NavScaffold(index: 2, child: AdminScanScreen()),
      ),
      GoRoute(
        path: '/admin/history',
        builder: (context, state) => const _NavScaffold(index: 3, child: AdminHistoryScreen()),
      ),
      GoRoute(
        path: '/admin/trash-types',
        builder: (context, state) => const TrashTypeManagementScreen(),
      ),
    ],
  );
});

/// Membungkus layar dengan bottom nav sesuai role pengguna.
///
/// Badge pengajuan hanya dihitung untuk admin dan memakai cache
/// [adminMetricsProvider], bukan query tambahan per navigasi.
class _NavScaffold extends ConsumerWidget {
  final int index;
  final Widget child;

  const _NavScaffold({required this.index, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = user?.isAdmin ?? false;
    final pendingCount = isAdmin
        ? (ref.watch(adminMetricsProvider).valueOrNull?.pendingCount ?? 0)
        : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(
        currentIndex: index,
        isAdmin: isAdmin,
        pendingCount: pendingCount,
        onTap: (target) {
          final tujuan = isAdmin
              ? const ['/admin/dashboard', '/admin/submissions', '/admin/scan', '/admin/history'][target]
              : const ['/dashboard', '/setor', '/history', '/profile'][target];
          if (target != index) context.go(tujuan);
        },
      ),
    );
  }
}
