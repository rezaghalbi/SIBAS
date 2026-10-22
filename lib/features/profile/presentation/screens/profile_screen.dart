import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Profil akun yang sedang login: identitas, peran, total berat, dan keluar.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Keluar Akun',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun SIBAS?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(currentUserProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentUserProvider);
    final user = userState.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeroHeader(
              title: 'Profil Saya',
              subtitle: user?.email ?? 'Memuat data akun...',
              trailing: IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/dashboard');
                  }
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              bottomContent: user == null
                  ? null
                  : GlassPanel(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initials(user.fullName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _roleLabel(user),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(
              child: userState.when(
                data: (data) {
                  if (data == null) {
                    return const _MessageBox(
                      icon: Icons.person_off_outlined,
                      text: 'Data akun tidak ditemukan. Silakan masuk kembali.',
                    );
                  }
                  return _ProfileCard(user: data);
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _MessageBox(
                  icon: Icons.cloud_off_rounded,
                  text: 'Gagal memuat profil. Periksa koneksi Anda.',
                  isError: true,
                  onRetry: () => ref.invalidate(currentUserProvider),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: user == null
                      ? null
                      : () => _confirmLogout(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Keluar'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel user;

  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final nim = (user.nim == null || user.nim!.trim().isEmpty)
        ? 'Belum diisi'
        : user.nim!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Akun',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Nama Lengkap', value: user.fullName),
          _InfoRow(label: 'Email', value: user.email.isEmpty ? 'Belum diisi' : user.email),
          _InfoRow(label: 'NIM', value: nim),
          _InfoRow(label: 'Peran', value: _roleLabel(user)),
          _InfoRow(
            label: 'Total Berat Sampah',
            value: '${user.totalWeight.toStringAsFixed(1)} kg',
          ),
          const SizedBox(height: 4),
          const Divider(height: 20, color: AppColors.borderLine),
          const Text(
            'Data profil belum bisa diubah dari aplikasi. Hubungi admin bila ada yang perlu diperbarui.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isError;
  final VoidCallback? onRetry;

  const _MessageBox({
    required this.icon,
    required this.text,
    this.isError = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isError ? AppColors.statusRejectedBg : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.borderLine,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: isError ? AppColors.danger : AppColors.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isError ? AppColors.danger : AppColors.textMuted,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

String _roleLabel(UserModel user) => user.isAdmin ? 'Admin' : 'Mahasiswa';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return 'S';
  final letters = parts.take(2).map((p) => p.substring(0, 1)).join();
  return letters.toUpperCase();
}
