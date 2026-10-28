import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tx_list_item.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../../../withdrawal/presentation/widgets/withdraw_qr_sheet.dart';
import '../../domain/models/transaction_model.dart';
import '../../../../core/theme/sibas_colors.dart';

/// Provider seluruh riwayat transaksi mahasiswa (limit 100)
final allStudentTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];

  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getStudentTransactions(user.id, limit: 100);
});

enum _HistoryTab { setoran, penarikan }

class HistoryScreen extends ConsumerStatefulWidget {
  /// Tab awal dari query `?tab=penarikan`; null berarti setoran.
  final String? initialTab;

  const HistoryScreen({super.key, this.initialTab});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const _filtersSetoran = [
    'Semua',
    'Menunggu Verifikasi',
    'Disetujui',
    'Ditolak',
    'Kedaluwarsa',
  ];

  static const _filtersPenarikan = [
    'Semua',
    'Menunggu Verifikasi',
    'Disetujui',
    'Ditolak',
  ];

  _HistoryTab _tab = _HistoryTab.setoran;
  String _selectedFilter = 'Semua';

  List<String> get _filters => _tab == _HistoryTab.setoran
      ? _filtersSetoran
      : _filtersPenarikan;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab == 'penarikan'
        ? _HistoryTab.penarikan
        : _HistoryTab.setoran;
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) return;
    final tab = widget.initialTab == 'penarikan'
        ? _HistoryTab.penarikan
        : _HistoryTab.setoran;
    if (tab != _tab) {
      setState(() {
        _tab = tab;
        _selectedFilter = 'Semua';
      });
    }
  }

  void _pilihTab(_HistoryTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _selectedFilter = 'Semua';
    });
  }

  bool _matchesFilter(TransactionModel tx) {
    if (_selectedFilter == 'Semua') return true;
    final status = tx.status.toUpperCase();
    if (_selectedFilter == 'Menunggu Verifikasi') return status == 'PENDING';
    if (_selectedFilter == 'Disetujui') return status == 'APPROVED';
    if (_selectedFilter == 'Ditolak') return status == 'REJECTED';
    if (_selectedFilter == 'Kedaluwarsa') return status == 'EXPIRED';
    return true;
  }

  /// Filter status untuk tab penarikan (tanpa status kedaluwarsa).
  bool _matchesWithdrawal(WithdrawalModel w) {
    if (_selectedFilter == 'Semua') return true;
    final status = w.status.toUpperCase();
    if (_selectedFilter == 'Menunggu Verifikasi') return status == 'PENDING';
    if (_selectedFilter == 'Disetujui') return status == 'APPROVED';
    if (_selectedFilter == 'Ditolak') return status == 'REJECTED';
    return true;
  }

  Future<void> _refresh() async {
    ref.invalidate(allStudentTransactionsProvider);
    ref.invalidate(studentWithdrawalsProvider);
    if (_tab == _HistoryTab.setoran) {
      await ref.read(allStudentTransactionsProvider.future);
    } else {
      await ref.read(studentWithdrawalsProvider.future);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(allStudentTransactionsProvider);
    final withdrawalState = ref.watch(studentWithdrawalsProvider);

    return Scaffold(
      backgroundColor: SibasColors.background,
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const _HistoryHead(),
              const SizedBox(height: 16),
              _HistoryTabSwitch(value: _tab, onChanged: _pilihTab),
              const SizedBox(height: 16),
              _StatusFilterBar(
                filters: _filters,
                selected: _selectedFilter,
                onSelected: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _tab == _HistoryTab.setoran
                    ? historyState.when(
                        data: _buildList,
                        loading: () => Center(
                          child: CircularProgressIndicator(
                            color: SibasColors.leaf,
                          ),
                        ),
                        error: (error, stackTrace) => RefreshIndicator(
                          onRefresh: _refresh,
                          color: SibasColors.leaf,
                          child: _centeredScrollable(
                            _HistoryError(
                              onRetry: () { _refresh(); },
                            ),
                          ),
                        ),
                      )
                    : withdrawalState.when(
                        data: _buildWithdrawals,
                        loading: () => Center(
                          child: CircularProgressIndicator(
                            color: SibasColors.leaf,
                          ),
                        ),
                        error: (error, stackTrace) => RefreshIndicator(
                          onRefresh: _refresh,
                          color: SibasColors.leaf,
                          child: _centeredScrollable(
                            _HistoryError(
                              onRetry: () { _refresh(); },
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<TransactionModel> transactions) {
    final filtered = transactions.where(_matchesFilter).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      color: SibasColors.leaf,
      child: filtered.isEmpty
          ? _centeredScrollable(
              _HistoryEmpty(
                filter: _selectedFilter,
                onResetFilter: _selectedFilter == 'Semua'
                    ? null
                    : () => setState(() => _selectedFilter = 'Semua'),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 96),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final tx = filtered[index];
                // QR bisa dibuka ulang selama masih PENDING; kedaluwarsa
                // ditandai watermark oleh QrDisplayScreen.
                final canShowQr =
                    tx.isPending && (tx.qrToken?.isNotEmpty ?? false);

                // `TxListItem` milik `core/widgets` (lane lain) dan belum
                // memasang tabular figures. Warisan gaya ini membuat nominal
                // dan berat tetap rata kolom tanpa mengubah widget bersama.
                return DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  child: TxListItem(
                    categoryName: tx.categoryName,
                    weightKg: tx.weight,
                    amountRp: tx.finalAmount ?? tx.estimatedAmount,
                    status: tx.status,
                    createdAt: tx.createdAt,
                    onTap: () => context.push('/transaction/${tx.id}'),
                    canShowQr: canShowQr,
                    onShowQr:
                        canShowQr ? () => context.push('/qr/${tx.id}') : null,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildWithdrawals(List<WithdrawalModel> items) {
    final filtered = items.where(_matchesWithdrawal).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      color: SibasColors.leaf,
      child: filtered.isEmpty
          ? _centeredScrollable(
              _HistoryEmpty(
                filter: _selectedFilter,
                isWithdrawal: true,
                onResetFilter: _selectedFilter == 'Semua'
                    ? null
                    : () => setState(() => _selectedFilter = 'Semua'),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4, bottom: 96),
              itemCount: filtered.length,
              itemBuilder: (context, index) =>
                  _WithdrawalHistoryTile(withdrawal: filtered[index]),
            ),
    );
  }

  /// Isi pendek (kosong atau gagal) tetap bisa ditarik untuk muat ulang dan
  /// diletakkan di tengah pada layar tinggi.
  Widget _centeredScrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryTabSwitch extends StatelessWidget {
  const _HistoryTabSwitch({required this.value, required this.onChanged});

  final _HistoryTab value;
  final ValueChanged<_HistoryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_HistoryTab>(
      expandedInsets: EdgeInsets.zero,
      segments: const [
        ButtonSegment<_HistoryTab>(
          value: _HistoryTab.setoran,
          label: Text('Setoran'),
        ),
        ButtonSegment<_HistoryTab>(
          value: _HistoryTab.penarikan,
          label: Text('Penarikan'),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 44)),
        textStyle: const WidgetStatePropertyAll<TextStyle>(
          TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? SibasColors.leaf
              : SibasColors.surfaceAlt;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : SibasColors.text;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: SibasColors.border),
        ),
      ),
    );
  }
}

/// Satu penarikan pada tab Riwayat mahasiswa.
class _WithdrawalHistoryTile extends StatelessWidget {
  const _WithdrawalHistoryTile({required this.withdrawal});

  final WithdrawalModel withdrawal;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final reason = (withdrawal.rejectionReason ?? '').trim();

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/withdrawal/${withdrawal.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: SibasColors.mintWash,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.payments_rounded,
                        color: SibasColors.leaf,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currency.format(withdrawal.amount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: SibasColors.text,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date.format(withdrawal.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: SibasColors.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          StatusBadge(status: withdrawal.status),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: SibasColors.muted,
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Alasan: $reason',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: SibasColors.status.badText,
                    ),
                  ),
                ],
                if (withdrawal.isPending &&
                    (withdrawal.qrToken?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 2),
                  TextButton.icon(
                    onPressed: () => showWithdrawQrSheet(
                      context,
                      token: withdrawal.qrToken!,
                      amount: withdrawal.amount,
                      status: withdrawal.status,
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      foregroundColor: SibasColors.leaf,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text('Tampilkan QR'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kepala halaman: label mikro, judul, dan satu baris penjelas (§3).
class _HistoryHead extends StatelessWidget {
  const _HistoryHead();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: SibasColors.leaf,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TRANSAKSI',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: SibasColors.leaf,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Riwayat Transaksi',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.1,
            color: SibasColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pantau status setoran dan penarikan sampah Anda.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: SibasColors.muted,
          ),
        ),
      ],
    );
  }
}

/// Baris chip status. Gulirannya hanya milik baris ini, bukan halaman (§8).
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          return _StatusFilterChip(
            label: filter,
            selected: filter == selected,
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
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
                ? SibasColors.leaf
                : SibasColors.mintWash,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected
                    ? SibasColors.leaf
                    : SibasColors.border,
              ),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.1,
                  color: selected ? Colors.white : SibasColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keadaan kosong: ikon, satu kalimat, dan aksi lanjut ke layar setor.
class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({
    required this.filter,
    this.isWithdrawal = false,
    this.onResetFilter,
  });

  final String filter;
  final bool isWithdrawal;
  final VoidCallback? onResetFilter;

  @override
  Widget build(BuildContext context) {
    final isAll = filter == 'Semua';

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: SibasColors.mintWash,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isWithdrawal
                  ? Icons.account_balance_wallet_outlined
                  : Icons.receipt_long_rounded,
              size: 30,
              color: SibasColors.leaf,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isAll
                ? (isWithdrawal ? 'Belum ada penarikan' : 'Belum ada setoran')
                : (isWithdrawal
                    ? 'Belum ada penarikan "$filter"'
                    : 'Belum ada setoran "$filter"'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: SibasColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAll
                ? (isWithdrawal
                    ? 'Pengajuan penarikan saldo akan muncul di sini beserta '
                        'statusnya.'
                    : 'Setoran yang Anda kirim akan muncul di sini beserta '
                        'status verifikasinya.')
                : (isWithdrawal
                    ? 'Coba pilih status lain untuk melihat penarikan Anda.'
                    : 'Coba pilih status lain untuk melihat setoran Anda.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: SibasColors.muted,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: () =>
                  context.go(isWithdrawal ? '/tarik' : '/setor'),
              style: FilledButton.styleFrom(
                backgroundColor: SibasColors.leaf,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: Icon(
                isWithdrawal ? Icons.savings_rounded : Icons.add_rounded,
                size: 18,
              ),
              label: Text(isWithdrawal ? 'Tarik Dana' : 'Setor Sampah'),
            ),
          ),
          if (onResetFilter != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onResetFilter,
              style: TextButton.styleFrom(
                foregroundColor: SibasColors.leaf,
                minimumSize: const Size(0, 44),
              ),
              child: const Text(
                'Tampilkan semua status',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Gagal memuat: pesan singkat + coba lagi, tanpa membocorkan detail error.
class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SibasColors.status.rejectedBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 26,
              color: SibasColors.status.badText,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Riwayat gagal dimuat',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: SibasColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Periksa koneksi Anda, lalu muat ulang riwayat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: SibasColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: SibasColors.leaf,
                side: BorderSide(color: SibasColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ),
        ],
      ),
    );
  }
}
