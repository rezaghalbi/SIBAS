import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Profil akun yang sedang login: identitas, peran, total berat, pengaturan
/// akun (nama, kata sandi, sesi), dan keluar.
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
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textMuted),
            ),
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

  Future<void> _openChangeName(BuildContext context, String currentName) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangeNameDialog(initialName: currentName),
    );
    if (saved != true || !context.mounted) return;
    _snack(context, 'Nama berhasil diperbarui');
  }

  Future<void> _openChangePassword(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (saved != true || !context.mounted) return;
    _snack(context, 'Kata sandi diperbarui');
  }

  Future<void> _openSignOutEverywhere(BuildContext context) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => const _SignOutEverywhereDialog(),
    );
    if (done != true || !context.mounted) return;
    // Sesi lokal sudah dibuang dialog; arahkan ke halaman masuk.
    context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentUserProvider);
    final user = userState.valueOrNull;
    final emailVerified = ref.watch(authRepositoryProvider).isEmailVerified;

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
                  return _ProfileCard(
                    user: data,
                    isEmailVerified: emailVerified,
                  );
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: GlassPanel(
                radius: 20,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      _MenuTile(
                        icon: Icons.info_outline_rounded,
                        label: 'Pusat Informasi',
                        onTap: () => context.push('/info'),
                      ),
                      const Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.borderLine,
                      ),
                      _MenuTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Riwayat Penarikan',
                        onTap: () => context.push('/saldo'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: GlassPanel(
                radius: 20,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      _MenuTile(
                        icon: Icons.badge_outlined,
                        label: 'Ubah Nama',
                        onTap: user == null
                            ? null
                            : () => _openChangeName(context, user.fullName),
                      ),
                      const Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.borderLine,
                      ),
                      _MenuTile(
                        icon: Icons.lock_reset_rounded,
                        label: 'Ubah Kata Sandi',
                        onTap: user == null
                            ? null
                            : () => _openChangePassword(context),
                      ),
                      const Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.borderLine,
                      ),
                      _MenuTile(
                        icon: Icons.devices_other_rounded,
                        label: 'Keluar dari semua perangkat',
                        color: AppColors.danger,
                        onTap: user == null
                            ? null
                            : () => _openSignOutEverywhere(context),
                      ),
                    ],
                  ),
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
  final bool isEmailVerified;

  const _ProfileCard({required this.user, required this.isEmailVerified});

  @override
  Widget build(BuildContext context) {
    final nim = (user.nim == null || user.nim!.trim().isEmpty)
        ? 'Belum diisi'
        : user.nim!;
    final statusColor = isEmailVerified
        ? AppColors.primaryMain
        : AppColors.statusPendingText;

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
          _InfoRow(
            label: 'Email',
            value: user.email.isEmpty ? 'Belum diisi' : user.email,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 120,
                  child: Text(
                    'Status Email',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isEmailVerified
                            ? Icons.verified_rounded
                            : Icons.error_outline_rounded,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isEmailVerified
                              ? 'Email terverifikasi'
                              : 'Email belum terverifikasi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isEmailVerified) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusPendingBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.statusPendingText.withValues(alpha: 0.35),
                ),
              ),
              child: const Text(
                'Verifikasi lewat tautan di kotak masuk email Anda. Bila tidak '
                'menerima email, minta admin mengirim ulang.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.statusPendingText,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _InfoRow(label: 'NIM', value: nim),
          _InfoRow(label: 'Peran', value: _roleLabel(user)),
          _InfoRow(
            label: 'Total Berat Sampah',
            value: '${user.totalWeight.toStringAsFixed(1)} kg',
          ),
          const SizedBox(height: 4),
          const Divider(height: 20, color: AppColors.borderLine),
          const Text(
            'Nama dan kata sandi bisa diubah lewat menu di bawah. Data lain '
            'hubungi admin bila perlu diperbarui.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primaryMain,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.mintSoftBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: AppColors.textMuted,
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

/// Banner galat yang menetap di dalam dialog sampai percobaan berikutnya.
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeNameDialog extends ConsumerStatefulWidget {
  final String initialName;

  const _ChangeNameDialog({required this.initialName});

  @override
  ConsumerState<_ChangeNameDialog> createState() => _ChangeNameDialogState();
}

class _ChangeNameDialogState extends ConsumerState<_ChangeNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateFullName(_name.text.trim());
      if (!mounted) return;
      ref.invalidate(currentUserProvider);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = pesanKesalahan(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Ubah Nama',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Nama lengkap',
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primaryMain,
                  size: 20,
                ),
              ),
              validator: (val) {
                final value = val?.trim() ?? '';
                if (value.isEmpty) return 'Nama wajib diisi';
                if (value.length > 80) return 'Nama maksimal 80 karakter';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _baru = TextEditingController();
  final _ulangi = TextEditingController();
  final List<bool> _obscure = List<bool>.filled(3, true);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _baru.dispose();
    _ulangi.dispose();
    super.dispose();
  }

  void _toggle(int index) {
    setState(() => _obscure[index] = !_obscure[index]);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(
        currentPassword: _current.text,
        newPassword: _baru.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = pesanKesalahan(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Ubah Kata Sandi',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kataSandiField(
              controller: _current,
              hint: 'Kata sandi saat ini',
              obscured: _obscure[0],
              onToggle: () => _toggle(0),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Kata sandi saat ini wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _kataSandiField(
              controller: _baru,
              hint: 'Kata sandi baru',
              obscured: _obscure[1],
              onToggle: () => _toggle(1),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Kata sandi baru wajib diisi';
                }
                if (val.length < 6) return 'Kata sandi baru minimal 6 karakter';
                if (val == _current.text) {
                  return 'Kata sandi baru tidak boleh sama dengan sandi lama';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _kataSandiField(
              controller: _ulangi,
              hint: 'Ulangi kata sandi baru',
              obscured: _obscure[2],
              onToggle: () => _toggle(2),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Ulangi kata sandi baru wajib diisi';
                }
                if (val != _baru.text) return 'Kata sandi tidak sama';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _kataSandiField({
    required TextEditingController controller,
    required String hint,
    required bool obscured,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscured,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.primaryMain,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textMuted,
            size: 20,
          ),
          tooltip: obscured ? 'Lihat kata sandi' : 'Sembunyikan kata sandi',
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}

class _SignOutEverywhereDialog extends ConsumerStatefulWidget {
  const _SignOutEverywhereDialog();

  @override
  ConsumerState<_SignOutEverywhereDialog> createState() =>
      _SignOutEverywhereDialogState();
}

class _SignOutEverywhereDialogState
    extends ConsumerState<_SignOutEverywhereDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signOutEverywhere();
    } catch (_) {
      // Sesi mungkin sudah tidak valid; pembersihan lokal tetap dijalankan.
    }
    try {
      // logout() memanggil signOut lagi — wajar, hanya memastikan state bersih.
      await ref.read(currentUserProvider.notifier).logout();
    } catch (_) {
      // Diabaikan: pengguna tetap diarahkan ke halaman masuk.
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Keluar dari Semua Perangkat',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'Semua sesi SIBAS di perangkat lain akan berakhir dan Anda perlu masuk '
        'kembali di perangkat tersebut. Lanjutkan?',
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Keluar'),
        ),
      ],
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

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
      ),
    );
}

String _roleLabel(UserModel user) => user.isAdmin ? 'Admin' : 'Mahasiswa';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return 'S';
  final letters = parts.take(2).map((p) => p.substring(0, 1)).join();
  return letters.toUpperCase();
}
