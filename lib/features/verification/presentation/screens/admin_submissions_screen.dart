import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../history/presentation/providers/transaction_provider.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../providers/verification_provider.dart';

enum _SubmissionTab { setoran, penarikan }

/// Pusat pengelolaan pengajuan admin: verifikasi setoran & penarikan saldo.
class AdminSubmissionsScreen extends ConsumerStatefulWidget {
  const AdminSubmissionsScreen({super.key});

  @override
  ConsumerState<AdminSubmissionsScreen> createState() =>
      _AdminSubmissionsScreenState();
}

class _AdminSubmissionsScreenState
    extends ConsumerState<AdminSubmissionsScreen> {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _date = DateFormat('dd/MM/yyyy HH:mm');

  static const _statusFilters = <String?, String>{
    null: 'Semua',
    'PENDING': 'Menunggu',
    'APPROVED': 'Disetujui',
    'REJECTED': 'Ditolak',
    'EXPIRED': 'Kedaluwarsa',
  };

  _SubmissionTab _tab = _SubmissionTab.setoran;
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeroHeader(
              title: 'Kelola Pengajuan',
              subtitle: 'Verifikasi setoran & pencairan saldo',
              trailing: IconButton(
                tooltip: 'Muat ulang',
                onPressed: () {
                  ref.invalidate(adminMetricsProvider);
                  ref.invalidate(adminTransactionsProvider);
                  ref.invalidate(adminWithdrawalsProvider(null));
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              bottomContent: SegmentedButton<_SubmissionTab>(
                segments: const [
                  ButtonSegment(
                    value: _SubmissionTab.setoran,
                    label: Text('Setoran'),
                    icon: Icon(Icons.inventory_2_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: _SubmissionTab.penarikan,
                    label: Text('Penarikan'),
                    icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                  ),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _tab = s.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                  selectedBackgroundColor: Colors.white,
                  selectedForegroundColor: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          if (_tab == _SubmissionTab.setoran)
            ..._setoranSlivers()
          else
            ..._penarikanSlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Setoran

  List<Widget> _setoranSlivers() {
    final txState = ref.watch(adminTransactionsProvider);
    final filter = ref.watch(adminFilterProvider);

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        sliver: SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in _statusFilters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: filter.status == entry.key,
                      selectedColor: AppColors.primaryMain,
                      backgroundColor: AppColors.cardSurface,
                      side: const BorderSide(color: AppColors.borderLine),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: filter.status == entry.key
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      onSelected: (_) {
                        ref.read(adminFilterProvider.notifier).update(
                              (f) => entry.key == null
                                  ? f.copyWith(clearStatus: true)
                                  : f.copyWith(status: entry.key),
                            );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      txState.when(
        data: (list) {
          if (list.isEmpty) {
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _emptyCard(
                  icon: Icons.inbox_rounded,
                  title: 'Belum ada setoran',
                  message: 'Tidak ada setoran pada filter status ini.',
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => _setoranCard(list[i]),
            ),
          );
        },
        loading: () => const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (_, __) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _errorCard(
              message: 'Gagal memuat daftar setoran. Periksa koneksi Anda.',
              onRetry: () => ref.invalidate(adminTransactionsProvider),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _setoranCard(Map<String, dynamic> item) {
    final profile = item['profiles'] as Map<String, dynamic>?;
    final category = item['trash_types'] as Map<String, dynamic>?;

    final id = item['id'] as String? ?? '';
    final status = (item['status'] as String?) ?? 'PENDING';
    final isPending = status.toUpperCase() == 'PENDING';
    final busy = _busyId == id;
    final reason = (item['rejection_reason'] as String?)?.trim() ?? '';

    final name = (profile?['full_name'] as String?) ?? 'Mahasiswa';
    final nim = (profile?['nim'] as String?) ?? '-';
    final categoryName = (category?['name'] as String?) ?? 'Sampah';
    final weight = (item['weight'] as num?)?.toDouble() ?? 0.0;
    final txCode = (item['tx_code'] as String?) ?? '-';
    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'] as String)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.mintSoftBackground,
                child: Icon(Icons.eco_rounded, color: AppColors.primaryMain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIM: $nim • $categoryName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.scale_rounded,
                size: 16,
                color: AppColors.primaryMain,
              ),
              const SizedBox(width: 6),
              Text(
                '${weight.toStringAsFixed(2)} kg',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                createdAt == null ? '-' : _date.format(createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Kode: $txCode',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          if (status.toUpperCase() == 'REJECTED' && reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.statusRejectedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Alasan ditolak: $reason',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.statusRejectedText,
                ),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            if (busy)
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Memproses...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _approveSetoran(item),
                      child: const Text('Setujui'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () => _rejectSetoran(item),
                      child: const Text('Tolak'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _approveSetoran(Map<String, dynamic> item) async {
    final id = item['id'] as String? ?? '';
    if (id.isEmpty) return;

    final confirmed = await _confirm(
      title: 'Setujui setoran?',
      message:
          'Saldo mahasiswa dan total berat akan bertambah sesuai setoran ini.',
      confirmLabel: 'Setujui',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = id);
    try {
      final status = await ref
          .read(verificationRepositoryProvider)
          .approveTransaction(transactionId: id);

      ref.invalidate(adminMetricsProvider);
      ref.invalidate(adminTransactionsProvider);
      ref.invalidate(currentUserProvider);
      // Detail transaksi yang mungkin masih terbuka ikut disegarkan.
      ref.invalidate(transactionDetailByIdProvider);

      final approved = status == 'APPROVED';
      _toast(
        approved
            ? 'Setoran disetujui dan saldo mahasiswa telah ditambahkan.'
            : 'QR sudah kedaluwarsa. Status berubah menjadi EXPIRED; '
                'minta mahasiswa mengajukan ulang.',
        isError: !approved,
      );
    } catch (_) {
      _toast(
        'Gagal menyetujui setoran. Periksa koneksi lalu coba lagi.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _rejectSetoran(Map<String, dynamic> item) async {
    final id = item['id'] as String? ?? '';
    if (id.isEmpty) return;

    final reason = await _askReason(
      title: 'Tolak setoran',
      hint: 'Contoh: sampah tercampur cairan atau kotor',
    );
    if (reason == null || !mounted) return;

    setState(() => _busyId = id);
    try {
      final status = await ref
          .read(verificationRepositoryProvider)
          .rejectTransaction(transactionId: id, reason: reason);

      ref.invalidate(adminMetricsProvider);
      ref.invalidate(adminTransactionsProvider);
      ref.invalidate(currentUserProvider);
      // Detail transaksi yang mungkin masih terbuka ikut disegarkan.
      ref.invalidate(transactionDetailByIdProvider);

      final rejected = status == 'REJECTED';
      _toast(
        rejected
            ? 'Setoran ditolak. Alasan sudah dicatat.'
            : 'QR sudah kedaluwarsa. Status berubah menjadi EXPIRED.',
        isError: !rejected,
      );
    } catch (_) {
      _toast(
        'Gagal menolak setoran. Periksa koneksi lalu coba lagi.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // -------------------------------------------------------------- Penarikan

  List<Widget> _penarikanSlivers() {
    final state = ref.watch(adminWithdrawalsProvider(null));

    return [
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Pengajuan pencairan saldo mahasiswa',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
      state.when(
        data: (list) {
          if (list.isEmpty) {
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _emptyCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Belum ada penarikan',
                  message: 'Pengajuan pencairan saldo akan tampil di sini.',
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => _penarikanCard(list[i]),
            ),
          );
        },
        loading: () => const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        error: (_, __) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _errorCard(
              message: 'Gagal memuat daftar penarikan. Periksa koneksi Anda.',
              onRetry: () => ref.invalidate(adminWithdrawalsProvider(null)),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _penarikanCard(WithdrawalModel w) {
    final busy = _busyId == w.id;
    final reason = (w.rejectionReason ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.mintSoftBackground,
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primaryMain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.studentName ?? 'Mahasiswa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIM: ${w.studentNim ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: w.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _currency.format(w.amount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const Spacer(),
              Text(
                _date.format(w.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.statusRejectedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Alasan ditolak: $reason',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.statusRejectedText,
                ),
              ),
            ),
          ],
          if (w.isPending) ...[
            const SizedBox(height: 12),
            if (busy)
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Memproses...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _approveWithdrawal(w.id),
                      child: const Text('Setujui'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      onPressed: () => _rejectWithdrawal(w.id),
                      child: const Text('Tolak'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _approveWithdrawal(String id) async {
    final confirmed = await _confirm(
      title: 'Setujui penarikan?',
      message: 'Saldo mahasiswa akan berkurang sesuai nominal pengajuan.',
      confirmLabel: 'Setujui',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = id);
    final controller = ref.read(withdrawalControllerProvider.notifier);
    final ok = await controller.approve(id);
    if (!mounted) return;
    setState(() => _busyId = null);

    if (ok) {
      _toast('Penarikan disetujui.');
    } else {
      _toast(
        _humanize(
          ref.read(withdrawalControllerProvider).error,
          'Gagal menyetujui penarikan. Coba lagi.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _rejectWithdrawal(String id) async {
    final reason = await _askReason(
      title: 'Tolak penarikan',
      hint: 'Contoh: data rekening tidak valid',
    );
    if (reason == null || !mounted) return;

    setState(() => _busyId = id);
    final controller = ref.read(withdrawalControllerProvider.notifier);
    final ok = await controller.reject(id, reason);
    if (!mounted) return;
    setState(() => _busyId = null);

    if (ok) {
      _toast('Penarikan ditolak. Alasan sudah dicatat.');
    } else {
      _toast(
        _humanize(
          ref.read(withdrawalControllerProvider).error,
          'Gagal menolak penarikan. Coba lagi.',
        ),
        isError: true,
      );
    }
  }

  // ------------------------------------------------------------------ Umum

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Dialog alasan tolak; tombol nonaktif sampai alasan terisi.
  Future<String?> _askReason({
    required String title,
    required String hint,
  }) async {
    var reason = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            autofocus: true,
            maxLines: 3,
            onChanged: (v) => setDialogState(() => reason = v),
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: reason.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, reason.trim()),
              child: const Text('Tolak Pengajuan'),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primaryDark,
      ),
    );
  }

  /// Pesan exception Indonesia ditampilkan apa adanya, selain itu generik.
  String _humanize(Object? error, String fallback) {
    final raw =
        (error?.toString() ?? '').replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) return fallback;
    const triggers = [
      'tidak',
      'gagal',
      'saldo',
      'wajib',
      'sudah',
      'belum',
      'harus',
      'sedang',
      'alasan',
      'minimal',
      'melebihi',
      'penarikan',
      'setoran',
      'kedaluwarsa',
    ];
    final lower = raw.toLowerCase();
    return triggers.any((t) => lower.contains(t)) ? raw : fallback;
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _errorCard({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.statusRejectedBg),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 34,
            color: AppColors.danger,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
