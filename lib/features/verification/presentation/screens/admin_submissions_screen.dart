import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../history/presentation/providers/transaction_provider.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../providers/verification_provider.dart';

enum _SubmissionTab { setoran, penarikan }

/// Target sentuh minimum (§1, §4).
const double _touchTarget = 44;

/// Ukuran ikon dalam kartu pengajuan.
const double _iconBox = 44;

/// Angka uang, berat, dan jumlah memakai lebar digit tetap (§3).
const List<FontFeature> _numbers = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// Judul seksi: 15.5 w700, tracking -0.2 (§3).
const TextStyle _sectionTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: AppColors.textPrimary,
);

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
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(adminFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _WidthLimit(
              child: HeroHeader(
                title: 'Kelola Pengajuan',
                subtitle: 'Setoran & pencairan saldo',
                trailing: IconButton(
                  tooltip: 'Muat ulang',
                  onPressed: () {
                    ref.invalidate(adminMetricsProvider);
                    ref.invalidate(adminTransactionsProvider);
                    ref.invalidate(adminWithdrawalsProvider(null));
                  },
                  icon: Container(
                    width: 40,
                    height: 40,
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
                bottomContent: _TabSwitch(
                  value: _tab,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
              ),
            ),
          ),
          if (_tab == _SubmissionTab.setoran)
            ..._setoranSlivers()
          else
            ..._penarikanSlivers(),
          // Nav mengambang tidak boleh menutup aksi terakhir (§4, §8).
          SliverToBoxAdapter(
            child: SizedBox(height: 96 + bottomInset),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Setoran

  List<Widget> _setoranSlivers() {
    final txState = ref.watch(adminTransactionsProvider);
    final filter = ref.watch(adminFilterProvider);
    final searching = filter.query.trim().isNotEmpty;
    final total = txState.valueOrNull?.length;

    return [
      SliverToBoxAdapter(
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _searchField(showClear: filter.query.isNotEmpty),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _statusBar(selected: filter.status),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daftar setoran',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _sectionTitle,
                  ),
                ),
                if (total != null)
                  Text(
                    '$total pengajuan',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      fontFeatures: _numbers,
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
            return _stateSliver(
              _emptySetoran(
                searching: searching,
                hasStatus: filter.status != null,
              ),
            );
          }
          return SliverList.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => ContentWidth(
              child: _setoranCard(list[i]),
            ),
          );
        },
        loading: () => _stateSliver(const _LoadingCard()),
        error: (_, __) => _stateSliver(
          _StateCard(
            icon: Icons.cloud_off_rounded,
            title: 'Gagal memuat setoran',
            message: 'Periksa koneksi Anda, lalu muat ulang daftar.',
            actionLabel: 'Coba lagi',
            onAction: () => ref.invalidate(adminTransactionsProvider),
          ),
        ),
      ),
    ];
  }

  Widget _stateSliver(Widget child) {
    return SliverToBoxAdapter(
      child: ContentWidth(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _searchField({required bool showClear}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (val) {
          ref.read(adminFilterProvider.notifier).update(
                (f) => f.copyWith(query: val),
              );
        },
        // 16 px agar Safari iOS tidak memperbesar halaman (§9).
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          hintText: 'Cari nama, NIM, atau kode',
          hintMaxLines: 1,
          hintStyle: const TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primaryMain,
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: showClear
              ? IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: _clearQuery,
                )
              : null,
        ),
      ),
    );
  }

  /// Chip status menggulir sendiri di dalam barisnya, bukan halaman (§8).
  Widget _statusBar({required String? selected}) {
    return SizedBox(
      height: _touchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = _statusFilters.entries.elementAt(index);
          return _FilterChip(
            label: entry.value,
            selected: selected == entry.key,
            onTap: () {
              ref.read(adminFilterProvider.notifier).update(
                    (f) => entry.key == null
                        ? f.copyWith(clearStatus: true)
                        : f.copyWith(status: entry.key),
                  );
            },
          );
        },
      ),
    );
  }

  void _clearQuery() {
    _searchController.clear();
    ref.read(adminFilterProvider.notifier).update(
          (f) => f.copyWith(query: ''),
        );
  }

  Widget _emptySetoran({
    required bool searching,
    required bool hasStatus,
  }) {
    if (searching) {
      return _StateCard(
        icon: Icons.search_off_rounded,
        title: 'Tidak ada hasil',
        message: 'Tidak ada setoran yang cocok dengan pencarian Anda.',
        actionLabel: 'Hapus pencarian',
        onAction: _clearQuery,
      );
    }
    if (!hasStatus) {
      return _StateCard(
        icon: Icons.inbox_rounded,
        title: 'Belum ada setoran',
        message: 'Pengajuan setoran mahasiswa akan tampil di sini.',
        actionLabel: 'Muat ulang',
        onAction: () => ref.invalidate(adminTransactionsProvider),
      );
    }
    return _StateCard(
      icon: Icons.filter_alt_rounded,
      title: 'Tidak ada pada status ini',
      message: 'Coba pilih status lain untuk melihat pengajuan.',
      actionLabel: 'Tampilkan semua',
      onAction: () {
        ref.read(adminFilterProvider.notifier).update(
              (f) => f.copyWith(clearStatus: true),
            );
      },
    );
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
    final amount =
        (item['final_amount'] ?? item['estimated_amount']) as num?;
    final txCode = (item['tx_code'] as String?) ?? '-';
    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'] as String)
        : null;

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconBox(icon: Icons.eco_rounded),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIM $nim',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        fontFeatures: _numbers,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusBadge(status: status),
              const Spacer(),
              Text(
                createdAt == null ? '-' : _date.format(createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontFeatures: _numbers,
                ),
              ),
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
              const SizedBox(width: 8),
              Text(
                '${weight.toStringAsFixed(2)} kg',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFeatures: _numbers,
                ),
              ),
              const Spacer(),
              if (amount != null)
                Flexible(
                  child: Text(
                    _currency.format(amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                      fontFeatures: _numbers,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Kode: $txCode',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          if (status.toUpperCase() == 'REJECTED' && reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ReasonNote(reason: reason),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            if (busy)
              const _BusyNote()
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: _approveStyle,
                      onPressed: () => _approveSetoran(item),
                      child: const Text('Setujui'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: _rejectStyle,
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
      ref.invalidate(transactionDetailRpcProvider);

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
      ref.invalidate(transactionDetailRpcProvider);

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
    final total = state.valueOrNull?.length;

    return [
      SliverToBoxAdapter(
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pengajuan pencairan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _sectionTitle,
                  ),
                ),
                if (total != null)
                  Text(
                    '$total pengajuan',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      fontFeatures: _numbers,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      state.when(
        data: (list) {
          if (list.isEmpty) {
            return _stateSliver(
              _StateCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Belum ada penarikan',
                message: 'Pengajuan pencairan saldo akan tampil di sini.',
                actionLabel: 'Muat ulang',
                onAction: () {
                  ref.invalidate(adminWithdrawalsProvider(null));
                },
              ),
            );
          }
          return SliverList.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => ContentWidth(
              child: _penarikanCard(list[i]),
            ),
          );
        },
        loading: () => _stateSliver(const _LoadingCard()),
        error: (_, __) => _stateSliver(
          _StateCard(
            icon: Icons.cloud_off_rounded,
            title: 'Gagal memuat penarikan',
            message: 'Periksa koneksi Anda, lalu muat ulang daftar.',
            actionLabel: 'Coba lagi',
            onAction: () {
              ref.invalidate(adminWithdrawalsProvider(null));
            },
          ),
        ),
      ),
    ];
  }

  Widget _penarikanCard(WithdrawalModel w) {
    final busy = _busyId == w.id;
    final reason = (w.rejectionReason ?? '').trim();

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/withdrawal/${w.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _IconBox(
                      icon: Icons.account_balance_wallet_outlined,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NIM ${w.studentNim ?? '-'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              fontFeatures: _numbers,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    StatusBadge(status: w.status),
                    const Spacer(),
                    Text(
                      _date.format(w.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFeatures: _numbers,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currency.format(w.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    fontFeatures: _numbers,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ReasonNote(reason: reason),
                ],
                if (w.isPending) ...[
                  const SizedBox(height: 12),
                  if (busy)
                    const _BusyNote()
                  else
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: _approveStyle,
                            onPressed: () => _approveWithdrawal(w.id),
                            child: const Text('Setujui'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: _rejectStyle,
                            onPressed: () => _rejectWithdrawal(w.id),
                            child: const Text('Tolak'),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
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
          borderRadius: BorderRadius.circular(20),
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
            borderRadius: BorderRadius.circular(20),
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
}

// ---------------------------------------------------------------- Widget

/// Batas lebar 1120 px agar kartu sejajar dengan hero di desktop (§4).
class _WidthLimit extends StatelessWidget {
  const _WidthLimit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: child,
      ),
    );
  }
}

/// Gaya tombol setujui: hijau, tinggi 44 px, radius 12.
final ButtonStyle _approveStyle = FilledButton.styleFrom(
  backgroundColor: AppColors.primaryMain,
  foregroundColor: Colors.white,
  elevation: 0,
  minimumSize: const Size(0, _touchTarget),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
  ),
);

/// Gaya tombol tolak: garis merah, tinggi 44 px, radius 12.
final ButtonStyle _rejectStyle = OutlinedButton.styleFrom(
  foregroundColor: AppColors.danger,
  minimumSize: const Size(0, _touchTarget),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  side: const BorderSide(color: AppColors.danger),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
  ),
);

/// Ikon kategori dalam kotak 44 px dengan isian mint.
class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _iconBox,
      height: _iconBox,
      decoration: BoxDecoration(
        color: AppColors.mintSoftBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.primaryMain, size: 22),
    );
  }
}

/// Catatan alasan penolakan, lembut tanpa bayangan.
class _ReasonNote extends StatelessWidget {
  const _ReasonNote({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SurfaceCard(
        tone: SurfaceTone.subtle,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: AppColors.statusRejectedBg,
        child: Text(
          'Alasan ditolak: $reason',
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.statusRejectedText,
          ),
        ),
      ),
    );
  }
}

/// Indikator proses singkat saat aksi berjalan.
class _BusyNote extends StatelessWidget {
  const _BusyNote();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: _touchTarget,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'Memproses...',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Sub-tab Setoran/Penarikan: dua pil penuh, tinggi 44 px, tanpa label
/// terpotong di 360 px (§3).
class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.value, required this.onChanged});

  final _SubmissionTab value;
  final ValueChanged<_SubmissionTab> onChanged;

  static const _labels = <_SubmissionTab, String>{
    _SubmissionTab.setoran: 'Setoran',
    _SubmissionTab.penarikan: 'Penarikan',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          for (final tab in _SubmissionTab.values)
            Expanded(
              child: _TabSegment(
                label: _labels[tab] ?? '',
                selected: tab == value,
                onTap: () => onChanged(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  const _TabSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: ShapeDecoration(
            color: selected ? Colors.white : Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Container(
              height: _touchTarget,
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? AppColors.primaryDark
                      : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip filter status 44 px; gulir hanya di dalam barisnya (§4, §8).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: ShapeDecoration(
            color: selected
                ? AppColors.primaryMain
                : AppColors.mintSoftBackground,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected
                    ? AppColors.primaryMain
                    : AppColors.borderLine,
              ),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Container(
              height: _touchTarget,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keadaan kosong/gagal: ikon, satu kalimat, dan aksi (§6).
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;

    return SizedBox(
      width: double.infinity,
      child: SurfaceCard(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.mintSoftBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 30, color: AppColors.primaryMain),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _sectionTitle,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            if (label != null && onAction != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: _touchTarget,
                child: OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(label),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryMain,
                    side: const BorderSide(color: AppColors.borderLine),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Keadaan memuat: satu baris penjelas, tanpa teks mentah.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: SurfaceCard(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 12),
            Text(
              'Memuat pengajuan...',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
