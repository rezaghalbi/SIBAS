import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/bank_location/presentation/screens/admin_locations_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/deposit/presentation/screens/qr_display_screen.dart';
import '../../features/deposit/presentation/screens/setor_screen.dart';
import '../../features/history/presentation/screens/admin_history_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/history/presentation/screens/transaction_detail_screen.dart';
import '../../features/info/presentation/screens/admin_settings_screen.dart';
import '../../features/info/presentation/screens/info_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/saldo/presentation/screens/saldo_screen.dart';
import '../../features/students/presentation/screens/admin_students_screen.dart';
import '../../features/trash_type/presentation/screens/trash_type_form_screen.dart';
import '../../features/trash_type/presentation/screens/trash_type_management_screen.dart';
import '../../features/verification/presentation/providers/verification_provider.dart';
import '../../features/verification/presentation/screens/admin_dashboard_screen.dart';
import '../../features/verification/presentation/screens/admin_manage_screen.dart';
import '../../features/verification/presentation/screens/admin_scan_screen.dart';
import '../../features/verification/presentation/screens/admin_submissions_screen.dart';
import '../../features/withdrawal/presentation/screens/tarik_screen.dart';
import '../../features/withdrawal/presentation/screens/withdrawal_detail_screen.dart';
import '../widgets/adaptive_shell.dart';

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

  // Sesi pemulihan sandi juga memicu redirect, jadi ikut jadi pemicu router.
  final recoveryNotifier = ValueNotifier<bool>(
    ref.read(passwordRecoveryProvider),
  );
  ref.listen<bool>(passwordRecoveryProvider, (_, next) {
    recoveryNotifier.value = next;
  });
  ref.onDispose(recoveryNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: Listenable.merge([authNotifier, recoveryNotifier]),
    redirect: (context, state) {
      final authState = authNotifier.value;
      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final location = state.matchedLocation;

      // Sesi pemulihan: paksa layar atur sandi baru sampai sandi disimpan.
      if (recoveryNotifier.value) {
        if (user == null) return '/login';
        return location == '/reset-password' ? null : '/reset-password';
      }
      if (location == '/reset-password') {
        if (user == null) return '/login';
        return user.isAdmin ? '/admin/dashboard' : '/dashboard';
      }

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
      const ruteMahasiswa = [
        '/dashboard',
        '/setor',
        '/tarik',
        '/history',
        '/saldo',
        '/profile',
        '/profile/edit',
        '/info',
      ];
      // Detail transaksi boleh dibuka admin maupun mahasiswa.
      final isRuteMahasiswa = ruteMahasiswa.contains(location) ||
          location.startsWith('/qr');
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
      // Tanpa scaffold bottom nav: wajib berdiri sendiri selama pemulihan.
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      // Mahasiswa — bottom nav tetap, isi tab disimpan IndexedStack.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _NavScaffold(navigationShell: navigationShell, isAdmin: false),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/setor',
                builder: (context, state) => const SetorScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tarik',
                builder: (context, state) => const TarikScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => HistoryScreen(
                  initialTab: state.uri.queryParameters['tab'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
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
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
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
      GoRoute(
        path: '/withdrawal/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return WithdrawalDetailScreen(withdrawalId: id);
        },
      ),
      GoRoute(
        path: '/admin/students',
        builder: (context, state) => const AdminStudentsScreen(),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (context, state) => const AdminSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/locations',
        builder: (context, state) => const AdminLocationsScreen(),
      ),
      GoRoute(
        path: '/admin/trash-types',
        builder: (context, state) => const TrashTypeManagementScreen(),
      ),
      // Form jenis sampah berdiri sendiri (tanpa shell admin) supaya action
      // bar bawah tidak bertabrakan dengan nav mengambang.
      GoRoute(
        path: '/admin/trash-types/new',
        builder: (context, state) => const TrashTypeFormScreen(),
      ),
      GoRoute(
        path: '/admin/trash-types/:id/edit',
        builder: (context, state) {
          final extra = state.extra;
          return TrashTypeFormScreen(
            isEdit: true,
            initial: extra is Map<String, dynamic> ? extra : null,
          );
        },
      ),

      // Admin — shell terpisah agar tiap peran punya riwayat tab sendiri.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _NavScaffold(navigationShell: navigationShell, isAdmin: true),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/dashboard',
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/submissions',
                builder: (context, state) => const AdminSubmissionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/scan',
                builder: (context, state) => const AdminScanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/history',
                builder: (context, state) => AdminHistoryScreen(
                  initialTab: state.uri.queryParameters['tab'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/manage',
                builder: (context, state) => const AdminManageScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Membungkus shell tab dengan navigasi adaptif ([AdaptiveShell]): nav bawah
/// di layar sempit, rail samping mulai 900 px. Scaffold berada di luar
/// [navigationShell], jadi nav tidak ikut transisi dan state tab tetap hidup.
class _NavScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final bool isAdmin;

  const _NavScaffold({
    required this.navigationShell,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Badge pengajuan hanya untuk admin, memakai cache [adminMetricsProvider].
    final pendingCount = isAdmin
        ? (ref.watch(adminMetricsProvider).valueOrNull?.pendingCount ?? 0)
        : 0;

    return AdaptiveShell(
      navigationShell: navigationShell,
      currentIndex: navigationShell.currentIndex,
      isAdmin: isAdmin,
      pendingCount: pendingCount,
      onTap: (target) => navigationShell.goBranch(
        target,
        // Tap tab yang sedang aktif mengembalikan ke lokasi awal tab itu.
        initialLocation: target == navigationShell.currentIndex,
      ),
    );
  }
}
