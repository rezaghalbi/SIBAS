import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class MahasiswaDashboardScreen extends ConsumerWidget {
  const MahasiswaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Mahasiswa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () => ref.read(currentUserProvider.notifier).logout(),
          ),
        ],
      ),
      body: userState.when(
        data: (user) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 64, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'Selamat Datang, ${user?.fullName ?? "Mahasiswa"}!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (user?.nim != null) ...[
                const SizedBox(height: 4),
                Text('NIM: ${user!.nim}', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
