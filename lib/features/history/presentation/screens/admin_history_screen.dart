import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/status_helper.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/segmented_tab.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/tx_list_item.dart';
import '../../../verification/data/csv_export.dart';
import '../../../verification/data/csv_download_stub.dart'
    if (dart.library.js_interop) '../../../verification/data/csv_download_web.dart';
import '../../../verification/presentation/providers/verification_provider.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../../../../core/theme/sibas_colors.dart';
import '../../domain/models/admin_history_filter.dart';
import '../providers/admin_history_provider.dart';

/// Target sentuh minimum (§1, §4).
const double _touchTarget = 44;

/// Judul seksi: 15.5 w700, tracking -0.2 (§3).
TextStyle get _sectionTitle => TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: SibasColors.text,
);

/// Riwayat seluruh transaksi (setoran & penarikan) untuk Admin,
/// dengan filter status dan filter tanggal cepat.
enum _HistoryTab { setoran, penarikan }

class AdminHistoryScreen extends ConsumerStatefulWidget {
  /// Tab awal dari query `?tab=penarikan`; null berarti setoran.
  final String? initialTab;

  const AdminHistoryScreen({super.key, this.initialTab});

  @override
  ConsumerState<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends ConsumerState<AdminHistoryScreen> {
  static const _statusesSetoran = <String?>[
    null,
    'PENDING',
    'APPROVED',
    'REJECTED',
    'EXPIRED',
  ];

  static const _statusesPenarikan = <String?>[
    null,
    'PENDING',
    'APPROVED',
    'REJECTED',
  ];

  _HistoryTab _tab = _HistoryTab.setoran;

  List<String?> get _statuses =>
      _tab == _HistoryTab.setoran ? _statusesSetoran : _statusesPenarikan;

  /// null = Semua, 1 = hari ini, 7 = 7 hari terakhir
  static const _dayFilters = <int?>[null, 1, 7];

  late final TextEditingController _searchController;
  bool _mengekspor = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab == 'penarikan'
        ? _HistoryTab.penarikan
        : _HistoryTab.setoran;
    if (_tab == _HistoryTab.penarikan &&
        ref.read(adminHistoryFilterProvider).status == 'EXPIRED') {
      ref.read(adminHistoryFilterProvider.notifier).update(
            (f) => f.copyWith(clearStatus: true),
          );
    }
    _searchController = TextEditingController(
      text: ref.read(adminHistoryFilterProvider).query,
    );
  }

  @override
  void didUpdateWidget(covariant AdminHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) return;
    final tab = widget.initialTab == 'penarikan'
        ? _HistoryTab.penarikan
        : _HistoryTab.setoran;
    if (tab != _tab) setState(() => _tab = tab);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Kalender lokal untuk chip tanggal; juga dipakai ekspor.
  void _pilihHari(int? days) {
    ref.read(adminHistoryFilterProvider.notifier).update((f) {
      if (days == null) return f.copyWith(clearDates: true);
      final rentang = AdminHistoryFilter.rentangHari(days);
      return f.copyWith(startDate: rentang.start, endDate: rentang.end);
    });
  }

  void _pilihTab(_HistoryTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == _HistoryTab.penarikan &&
        ref.read(adminHistoryFilterProvider).status == 'EXPIRED') {
      ref.read(adminHistoryFilterProvider.notifier).update(
            (f) => f.copyWith(clearStatus: true),
          );
    }
  }

  void _pilihStatus(String? status) {
    ref.read(adminHistoryFilterProvider.notifier).update(
          (f) => status == null
              ? f.copyWith(clearStatus: true)
              : f.copyWith(status: status),
        );
  }

  /// Chip hari yang sedang aktif, atau null bila bukan rentang preset.
  static int? _hariAktif(AdminHistoryFilter filter) {
    for (final days in _dayFilters) {
      if (days == null) continue;
      final rentang = AdminHistoryFilter.rentangHari(days);
      if (filter.startDate == rentang.start && filter.endDate == rentang.end) {
        return days;
      }
    }
    return null;
  }

  static String _dayLabel(int? days) {
    if (days == null) return 'Semua tanggal';
    if (days == 1) return 'Hari ini';
    return '7 hari';
  }

  /// Ekspor seluruh setoran yang cocok dengan filter aktif (bukan hanya
  /// baris yang sudah tampil di layar).
  Future<void> _eksporSetoran() async {
    final filter = ref.read(adminHistoryFilterProvider);
    final repo = ref.read(verificationRepositoryProvider);
    final locationId = ref.read(adminFilterProvider).locationId;
    setState(() => _mengekspor = true);
    try {
      final data = await repo.getAllTransactionsForExport(
        query: filter.query,
        statusFilter: filter.status,
        locationId: locationId,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
      if (!mounted) return;
      if (data.isEmpty) {
        _pesan('Tidak ada data untuk diekspor');
        return;
      }
      await _kirimCsv('rekap-setoran', bangunCsvSetoran(data));
    } catch (_) {
      if (!mounted) return;
      _pesan('Gagal memuat data setoran');
    } finally {
      if (mounted) setState(() => _mengekspor = false);
    }
  }

  /// Ekspor seluruh penarikan dengan status, pencarian, dan tanggal yang sama.
  Future<void> _eksporPenarikan() async {
    final filter = ref.read(adminHistoryFilterProvider);
    final repo = ref.read(withdrawalRepositoryProvider);
    final locationId = ref.read(adminFilterProvider).locationId;
    setState(() => _mengekspor = true);
    try {
      final data = await repo.getAllWithdrawalsForExport(
        statusFilter: filter.status,
        locationId: locationId,
        query: filter.query,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
      if (!mounted) return;
      if (data.isEmpty) {
        _pesan('Tidak ada data untuk diekspor');
        return;
      }
      await _kirimCsv('rekap-penarikan', bangunCsvPenarikan(data));
    } catch (_) {
      if (!mounted) return;
      _pesan('Gagal memuat data penarikan');
    } finally {
      if (mounted) setState(() => _mengekspor = false);
    }
  }

  /// Unduh CSV; bila unduhan tidak bisa dimulai (mis. Safari), salin ke klip.
  Future<void> _kirimCsv(String awalan, String csv) async {
    final terunduh = await simpanCsv('$awalan-${_capWaktu()}.csv', csv);
    if (!terunduh) {
      await Clipboard.setData(ClipboardData(text: csv));
    }
    if (!mounted) return;
    _pesan(terunduh ? 'CSV diunduh' : 'CSV disalin ke papan klip');
  }

  void _pesan(String teks) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  static String _capWaktu() {
    final now = DateTime.now();
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${dua(now.month)}${dua(now.day)}';
  }

  void _clearQuery() {
    _searchController.clear();
    ref.read(adminHistoryFilterProvider.notifier).update(
          (f) => f.copyWith(query: ''),
        );
  }

  void _resetFilters() {
    ref.read(adminHistoryFilterProvider.notifier).update(
          (f) => f.copyWith(clearStatus: true, clearDates: true),
        );
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(adminHistoryTransactionsProvider);
    final wdState = ref.watch(adminHistoryWithdrawalsProvider);
    final filter = ref.watch(adminHistoryFilterProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SibasColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WidthLimit(
              child: HeroHeader(
                title: 'Riwayat Transaksi',
                subtitle: 'Setoran & penarikan',
                trailing: _buildExportButton(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ContentWidth(
                child: SegmentedTab<_HistoryTab>(
                  value: _tab,
                  items: const {
                    _HistoryTab.setoran: 'Setoran',
                    _HistoryTab.penarikan: 'Penarikan',
                  },
                  onChanged: _pilihTab,
                ),
              ),
            ),
            Expanded(
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _searchField(
                      showClear: filter.query.isNotEmpty,
                      hint: _tab == _HistoryTab.setoran
                          ? 'Cari nama, NIM, atau kode'
                          : 'Cari nama atau NIM',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: _touchTarget,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _dayFilters.length + _statuses.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) =>
                            _filterChip(index, filter),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _tab == _HistoryTab.setoran
                          ? _buildSetoran(txState, filter, bottomInset)
                          : _buildPenarikan(wdState, filter, bottomInset),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    if (_mengekspor) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Ekspor CSV',
      padding: EdgeInsets.zero,
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.download_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      onSelected: (jenis) {
        if (_mengekspor) return;
        if (jenis == 'penarikan') {
          _eksporPenarikan();
          return;
        }
        _eksporSetoran();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'setoran',
          child: Text('Rekap setoran'),
        ),
        PopupMenuItem(
          value: 'penarikan',
          child: Text('Rekap penarikan'),
        ),
      ],
    );
  }

  Widget _buildSetoran(
    AsyncValue<List<Map<String, dynamic>>> txState,
    AdminHistoryFilter filter,
    double bottomInset,
  ) {
    return txState.when(
      data: (list) {
        if (list.isEmpty) {
          return _centeredState(
            _EmptyState(
              searching: filter.query.trim().isNotEmpty,
              hasFilter: filter.status != null || filter.hasDateFilter,
              isWithdrawal: false,
              onClearQuery: _clearQuery,
              onResetFilters: _resetFilters,
              onReload: () {
                ref.invalidate(adminHistoryTransactionsProvider);
              },
            ),
          );
        }
        final limit = ref.watch(adminPageLimitProvider);
        final adaLagi = list.length >= limit;
        return ListView.builder(
          padding: EdgeInsets.only(bottom: 96 + bottomInset),
          itemCount: list.length + (adaLagi ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == list.length) {
              return _muatLagi(limit);
            }
            return _historyRow(list[index]);
          },
        );
      },
      loading: () => _centeredState(const _LoadingCard()),
      error: (_, __) => _centeredState(
        _StateCard(
          icon: Icons.cloud_off_rounded,
          title: 'Riwayat gagal dimuat',
          message: 'Periksa koneksi Anda, lalu muat ulang riwayat.',
          actionLabel: 'Coba lagi',
          onAction: () {
            ref.invalidate(adminHistoryTransactionsProvider);
          },
        ),
      ),
    );
  }

  Widget _buildPenarikan(
    AsyncValue<List<WithdrawalModel>> state,
    AdminHistoryFilter filter,
    double bottomInset,
  ) {
    return state.when(
      data: (list) {
        if (list.isEmpty) {
          return _centeredState(
            _EmptyState(
              searching: filter.query.trim().isNotEmpty,
              hasFilter: filter.status != null || filter.hasDateFilter,
              isWithdrawal: true,
              onClearQuery: _clearQuery,
              onResetFilters: _resetFilters,
              onReload: () {
                ref.invalidate(adminHistoryWithdrawalsProvider);
              },
            ),
          );
        }
        final limit = ref.watch(adminPageLimitProvider);
        final adaLagi = list.length >= limit;
        return ListView.builder(
          padding: EdgeInsets.only(bottom: 96 + bottomInset),
          itemCount: list.length + (adaLagi ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == list.length) {
              return _muatLagi(limit);
            }
            return _withdrawalRow(list[index]);
          },
        );
      },
      loading: () => _centeredState(const _LoadingCard()),
      error: (_, __) => _centeredState(
        _StateCard(
          icon: Icons.cloud_off_rounded,
          title: 'Riwayat penarikan gagal dimuat',
          message: 'Periksa koneksi Anda, lalu muat ulang riwayat.',
          actionLabel: 'Coba lagi',
          onAction: () {
            ref.invalidate(adminHistoryWithdrawalsProvider);
          },
        ),
      ),
    );
  }

  Widget _muatLagi(int limit) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: OutlinedButton(
        onPressed: () =>
            ref.read(adminPageLimitProvider.notifier).state += 50,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: SibasColors.leaf,
          side: BorderSide(color: SibasColors.border),
        ),
        child: Text('Muat $limit riwayat lagi'),
      ),
    );
  }

  /// Keadaan pendek diletakkan di tengah dengan lebar baca terbatas.
  Widget _centeredState(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: child,
      ),
    );
  }

  Widget _filterChip(int index, AdminHistoryFilter filter) {
    final isDayChip = index < _dayFilters.length;
    final String label;
    final bool isSelected;

    if (isDayChip) {
      final days = _dayFilters[index];
      label = _dayLabel(days);
      isSelected = _hariAktif(filter) == days;
    } else {
      final status = _statuses[index - _dayFilters.length];
      label = status == null
          ? 'Semua status'
          : TransactionStatusHelper.toDisplayLabel(status);
      isSelected = filter.status == status;
    }

    return _FilterChip(
      label: label,
      selected: isSelected,
      onTap: () {
        if (isDayChip) {
          _pilihHari(_dayFilters[index]);
        } else {
          _pilihStatus(_statuses[index - _dayFilters.length]);
        }
      },
    );
  }

  Widget _searchField({required bool showClear, String? hint}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SibasColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SibasColors.border),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (val) {
          ref.read(adminHistoryFilterProvider.notifier).update(
                (f) => f.copyWith(query: val),
              );
        },
        // 16 px agar Safari iOS tidak memperbesar halaman (§9).
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: SibasColors.text,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          hintText: hint ?? 'Cari nama, NIM, atau kode',
          hintMaxLines: 1,
          hintStyle: TextStyle(
            fontSize: 15,
            color: SibasColors.muted,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: SibasColors.leaf,
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          suffixIcon: showClear
              ? IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: SibasColors.muted,
                  ),
                  onPressed: _clearQuery,
                )
              : null,
        ),
      ),
    );
  }

  /// Satu baris riwayat: `TxListItem` (kolom kanan tidak terpotong) dengan
  /// catatan nama mahasiswa. Aksi validasi hanya ada di layar Pengajuan.
  Widget _historyRow(Map<String, dynamic> item) {
    final profile = item['profiles'] as Map<String, dynamic>?;
    final category = item['trash_types'] as Map<String, dynamic>?;
    final name = (profile?['full_name'] as String?) ?? 'Mahasiswa';
    final nim = (profile?['nim'] as String?) ?? '-';
    final catName = (category?['name'] as String?) ?? 'Sampah';
    final weight = (item['weight'] != null)
        ? (item['weight'] as num).toDouble()
        : 0.0;
    final amount = (item['final_amount'] ?? item['estimated_amount']) as num?;
    final status = (item['status'] as String?) ?? 'PENDING';
    final created = DateTime.tryParse(
          (item['created_at'] as String?) ?? '',
        )?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final reason = (item['rejection_reason'] as String?)?.trim() ?? '';
    final id = item['id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TxListItem(
          categoryName: catName,
          weightKg: weight,
          amountRp: amount?.toDouble(),
          status: status,
          createdAt: created,
          nim: nim,
          showNim: true,
          onTap: () => context.push('/transaction/$id'),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: SibasColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: SibasColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (reason.isNotEmpty)
          SurfaceCard(
            margin: const EdgeInsets.only(bottom: 12),
            tone: SurfaceTone.subtle,
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: SibasColors.status.rejectedBackground,
            child: Text(
              'Alasan ditolak: $reason',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: SibasColors.status.rejectedText,
              ),
            ),
          ),
      ],
    );
  }

  /// Satu baris penarikan pada tab Riwayat (read-only).
  Widget _withdrawalRow(WithdrawalModel item) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final reason = (item.rejectionReason ?? '').trim();

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/withdrawal/${item.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              currency.format(item.amount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: SibasColors.text,
                              ),
                            ),
                          ),
                          StatusBadge(status: item.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.studentName ?? 'Mahasiswa'} • '
                        '${item.studentNim ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: SibasColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date.format(item.createdAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: SibasColors.muted,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Alasan: $reason',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SibasColors.status.badText,
                          ),
                        ),
                      ],
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
          ),
        ),
      ),
    );
  }
}

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

/// Chip filter 44 px; gulir hanya di dalam baris ini, bukan halaman (§8).
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

/// Keadaan kosong: ikon, satu kalimat, satu aksi yang relevan (§6).
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searching,
    required this.hasFilter,
    required this.isWithdrawal,
    required this.onClearQuery,
    required this.onResetFilters,
    required this.onReload,
  });

  final bool searching;
  final bool hasFilter;
  final bool isWithdrawal;
  final VoidCallback onClearQuery;
  final VoidCallback onResetFilters;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return _StateCard(
        icon: Icons.search_off_rounded,
        title: 'Tidak ada hasil',
        message: 'Tidak ada riwayat yang cocok dengan pencarian Anda.',
        actionLabel: 'Hapus pencarian',
        onAction: onClearQuery,
      );
    }
    if (!hasFilter) {
      return _StateCard(
        icon: isWithdrawal
            ? Icons.account_balance_wallet_outlined
            : Icons.receipt_long_rounded,
        title: isWithdrawal ? 'Belum ada penarikan' : 'Belum ada riwayat',
        message: isWithdrawal
            ? 'Pengajuan penarikan mahasiswa akan tampil di sini.'
            : 'Setoran mahasiswa akan tampil di sini setelah dikirim.',
        actionLabel: 'Muat ulang',
        onAction: onReload,
      );
    }
    return _StateCard(
      icon: Icons.filter_alt_rounded,
      title: 'Tidak ada pada filter ini',
      message: 'Coba pilih tanggal atau status lain.',
      actionLabel: 'Tampilkan semua',
      onAction: onResetFilters,
    );
  }
}

/// Kartu keadaan: ikon, satu kalimat, aksi 44 px (§6).
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
                color: SibasColors.mintWash,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 30, color: SibasColors.leaf),
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
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: SibasColors.muted,
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
    return const SkeletonList(items: 3, lines: 3);
  }
}
