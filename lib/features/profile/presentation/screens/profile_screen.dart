import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Lebar konten halaman pengaturan. Lebih sempit dari 1120 px (§4) agar baris
/// teks tidak melebar di desktop dengan rail.
const double _maxContentWidth = 720;

/// Jarak antar seksi pada skala 4 pt (§4).
const double _sectionGap = 24;

/// Radius kartu konten (r-20) sesuai §4.
const double _cardRadius = 20;

/// Target sentuh minimum 44 px (§1 butir 6, §4).
const double _touchTarget = 44;

/// Judul seksi Glass 2.0 (§3): 15.5 px, w700, tracking rapat.
const TextStyle _sectionTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  height: 1.25,
  color: AppColors.textPrimary,
);

/// Label baris sebagai metadata kecil (§3), bukan teks utama.
const TextStyle _rowLabel = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.1,
  height: 1.4,
  color: AppColors.textMuted,
);

/// Angka berat dan hitungan memakai lebar digit tetap (§3).
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Profil akun yang sedang login: identitas, peran, total berat, pengaturan
/// akun (nama, kata sandi, sesi), dan keluar.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  Future<void> _openChangePassword(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (saved != true || !context.mounted) return;
    _snack(context, 'Kata sandi diperbarui');
  }

  Future<void> _openChangeEmail(
    BuildContext context,
    String currentEmail,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangeEmailDialog(initialEmail: currentEmail),
    );
    if (saved != true || !context.mounted) return;
    _snack(
      context,
      'Tautan konfirmasi dikirim ke email baru. Periksa kotak masuk.',
    );
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

  Future<void> _openDeleteAccount(BuildContext context, WidgetRef ref) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted != true || !context.mounted) return;
    try {
      await ref.read(currentUserProvider.notifier).logout();
    } catch (_) {
      // Diabaikan: pengguna tetap diarahkan ke halaman masuk.
    }
    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentUserProvider);
    final user = userState.valueOrNull;
    final emailVerified = ref.watch(authRepositoryProvider).isEmailVerified;
    final avatarUrl = ref.watch(avatarUrlProvider).valueOrNull;
    final inisial = user == null
        ? const SizedBox.shrink()
        : Text(
            _initials(user.fullName),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _WidthLimit(
              child: HeroHeader(
                title: 'Profil Saya',
                subtitle: user?.email ?? 'Memuat data akun...',
                trailing: IconButton(
                  tooltip: 'Kembali',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: _touchTarget,
                    minHeight: _touchTarget,
                  ),
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
                // Satu-satunya kaca di layar ini: panel identitas di dalam
                // gradien hero (§7.1). Nav shell memakai kuota kedua.
                bottomContent: user == null
                    ? null
                    : GlassPanel(
                        tone: GlassTone.hero,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: avatarUrl == null
                                  ? inisial
                                  : Image.network(
                                      avatarUrl,
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => inisial,
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
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _roleLabel(user),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
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
          ),
          SliverToBoxAdapter(
            child: _ContentSection(
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
                loading: () => const _LoadingCard(),
                error: (_, __) => _MessageBox(
                  icon: Icons.cloud_off_rounded,
                  text: 'Gagal memuat profil. Periksa koneksi Anda.',
                  isError: true,
                  onRetry: () => ref.invalidate(currentUserProvider),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ContentSection(
              child: _MenuCard(
                items: [
                  _MenuTile(
                    icon: Icons.info_outline_rounded,
                    label: 'Pusat Informasi',
                    onTap: () => context.push('/info'),
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
          SliverToBoxAdapter(
            child: _ContentSection(
              child: _MenuCard(
                items: [
                  _MenuTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profil',
                    onTap: user == null
                        ? null
                        : () => context.push('/profile/edit'),
                  ),
                  _MenuTile(
                    icon: Icons.lock_reset_rounded,
                    label: 'Ubah Kata Sandi',
                    onTap: user == null
                        ? null
                        : () => _openChangePassword(context),
                  ),
                  _MenuTile(
                    icon: Icons.email_outlined,
                    label: 'Ubah Email',
                    onTap: user == null
                        ? null
                        : () => _openChangeEmail(context, user.email),
                  ),
                  _MenuTile(
                    icon: Icons.devices_other_rounded,
                    label: 'Keluar dari semua perangkat',
                    color: AppColors.danger,
                    onTap: user == null
                        ? null
                        : () => _openSignOutEverywhere(context),
                  ),
                  _MenuTile(
                    icon: Icons.no_accounts_rounded,
                    label: 'Hapus Akun',
                    color: AppColors.statusRejected,
                    onTap: user == null
                        ? null
                        : () => _openDeleteAccount(context, ref),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ContentSection(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: user == null
                      ? null
                      : () => _confirmLogout(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(
                      color: AppColors.danger,
                      width: 1.5,
                    ),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Keluar'),
                ),
              ),
            ),
          ),
          // Nav mengambang tidak boleh menutup tombol terakhir (§4).
          SliverToBoxAdapter(
            child: SizedBox(
              height: 96 + MediaQuery.paddingOf(context).bottom,
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
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Data Akun', style: _sectionTitle),
          const SizedBox(height: 16),
          _InfoRow(label: 'Nama Lengkap', value: user.fullName),
          _InfoRow(
            label: 'Email',
            value: user.email.isEmpty ? 'Belum diisi' : user.email,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 120,
                  child: Text('Status Email', style: _rowLabel),
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
            const SizedBox(height: 14),
          ],
          _InfoRow(label: 'NIM', value: nim),
          _InfoRow(label: 'Peran', value: _roleLabel(user)),
          _InfoRow(
            label: 'Total Berat Sampah',
            value: '${user.totalWeight.toStringAsFixed(1)} kg',
          ),
          const Divider(height: 24, color: AppColors.borderLine),
          const Text(
            'Nama, NIM, nomor WhatsApp, dan foto bisa diubah lewat menu Edit '
            'Profil. Data lain hubungi admin bila perlu diperbarui.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Daftar aksi sebagai satu kartu solid. Kaca hanya untuk lapisan mengambang
/// (§7.1), jadi grup menu tidak memakai `GlassPanel`.
class _MenuCard extends StatelessWidget {
  final List<Widget> items;

  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(
          const Divider(
            height: 1,
            indent: 62,
            endIndent: 16,
            color: AppColors.borderLine,
          ),
        );
      }
      children.add(items[i]);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// Satu baris menu. Seluruh permukaan baris bisa diketuk, tinggi minimal 56 px
/// sehingga target sentuh 44 px terpenuhi (§4).
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
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: enabled
                        ? AppColors.mintSoftBackground
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: enabled ? color : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: enabled
                      ? AppColors.textMuted
                      : AppColors.textMuted.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 120, child: Text(label, style: _rowLabel)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: AppColors.textPrimary,
                fontFeatures: _tabular,
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

class _ChangeEmailDialog extends ConsumerStatefulWidget {
  final String initialEmail;

  const _ChangeEmailDialog({required this.initialEmail});

  @override
  ConsumerState<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends ConsumerState<_ChangeEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// Wajib isi, ada `@` dan titik setelahnya, maksimal 120 karakter.
  String? _validate(String? val) {
    final value = val?.trim() ?? '';
    if (value.isEmpty) return 'Email wajib diisi';
    if (value.length > 120) return 'Email maksimal 120 karakter';
    final at = value.indexOf('@');
    if (at <= 0 || !value.substring(at + 1).contains('.')) {
      return 'Format email tidak valid';
    }
    if (value.toLowerCase() == widget.initialEmail.trim().toLowerCase()) {
      return 'Email baru sama dengan email saat ini';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changeEmail(_email.text.trim());
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Ubah Email',
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
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'Email baru',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: AppColors.primaryMain,
                  size: 20,
                ),
              ),
              validator: _validate,
            ),
            const SizedBox(height: 10),
            const Text(
              'Email lama tetap aktif sampai tautan konfirmasi diklik.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
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
              : const Text('Kirim Tautan'),
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
      await ref.read(currentUserProvider.notifier).ubahSandiDenganSandiLama(
            lama: _current.text,
            baru: _baru.text,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _pesanGantiSandi(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      // logout() memanggil signOut lagi — wajar, hanya memastikan state
      // bersih.
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  static const _kunciHapus = 'HAPUS';

  final _ketik = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ketik.dispose();
    super.dispose();
  }

  bool get _siap => _ketik.text == _kunciHapus;

  Future<void> _confirm() async {
    if (_busy || !_siap) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).hapusAkun();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = pesanKesalahan(e);
      });
    }
  }

  Widget _poin(String teks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(
              Icons.circle,
              size: 5,
              color: AppColors.statusRejected,
            ),
          ),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Hapus akun ini?',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _poin(
            'Akun ditandai terhapus dan tidak bisa dipakai untuk masuk lagi.',
          ),
          _poin('Nama, NIM, dan email dianonimkan.'),
          _poin(
            'Riwayat setoran dan penarikan tetap tersimpan untuk keperluan '
            'audit.',
          ),
          _poin(
            'Saldo harus nol dan tidak boleh ada pengajuan yang menunggu '
            'validasi.',
          ),
          _poin('Tindakan ini tidak bisa dibatalkan dari aplikasi.'),
          const SizedBox(height: 4),
          TextField(
            controller: _ketik,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Ketik HAPUS',
              helperText: 'Ketik HAPUS dengan huruf besar untuk melanjutkan.',
              helperMaxLines: 2,
              errorText: _ketik.text.isEmpty || _siap
                  ? null
                  : 'Teks belum sama dengan HAPUS',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
        ],
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
          onPressed: (_busy || !_siap) ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.statusRejected,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.statusRejected.withValues(
              alpha: 0.35,
            ),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
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
              : const Text('Hapus Akun'),
        ),
      ],
    );
  }
}

/// Kotak pesan untuk state kosong dan galat: kartu solid tanpa blur (§7.1).
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
    final accent = isError ? AppColors.danger : AppColors.primaryMain;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isError ? AppColors.statusRejectedBg : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(
          color: isError
              ? AppColors.danger.withValues(alpha: 0.24)
              : AppColors.borderLine,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isError
                  ? AppColors.danger.withValues(alpha: 0.10)
                  : AppColors.mintSoftBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: isError ? AppColors.danger : AppColors.textMuted,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(0, _touchTarget),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder saat data akun dimuat: satu kartu solid setinggi konten agar
/// halaman tidak meloncat saat data datang.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

/// Seksi konten: lebar maksimal 720 px dengan gutter 16/32 (§4, §10.5).
class _ContentSection extends StatelessWidget {
  final Widget child;

  /// Jarak atas dari seksi sebelumnya pada skala 4 pt.
  final double top;

  const _ContentSection({required this.child, this.top = _sectionGap});

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      maxWidth: _maxContentWidth,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: child,
      ),
    );
  }
}

/// Batas lebar yang sama untuk hero, agar tepi kartu sejajar dengan seksi.
class _WidthLimit extends StatelessWidget {
  final Widget child;

  const _WidthLimit({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );
  }
}

/// Pesan server soal kata sandi dipakai apa adanya (mis. "Kata sandi saat ini
/// salah."); pesan lain tetap lewat [pesanKesalahan].
String _pesanGantiSandi(Object error) {
  if (error is AuthException) {
    final pesan = error.message.trim();
    if (pesan.toLowerCase().contains('sandi')) return pesan;
  }
  return pesanKesalahan(error);
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
