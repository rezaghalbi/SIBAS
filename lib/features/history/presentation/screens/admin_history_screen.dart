import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/status_helper.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tx_list_item.dart';
import '../../../verification/data/csv_export.dart';
import '../../../verification/data/csv_download_stub.dart'
    if (dart.library.js_interop) '../../../verification/data/csv_download_web.dart';
import '../../../verification/presentation/providers/verification_provider.dart';
import '../../../verification/presentation/widgets/verification_bottom_sheet.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';

/// Target sentuh minimum (§1, §4).
const double _touchTarget = 44;

/// Judul seksi: 15.5 w700, tracking -0.2 (§3).
const TextStyle _sectionTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: AppColors.textPrimary,
);

/// Riwayat seluruh penyetoran (semua status) untuk Admin,
/// dengan filter status & filter tanggal cepat sesuai prd.md.
class AdminHistoryScreen extends ConsumerStatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  ConsumerState<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends ConsumerState<AdminHistoryScreen> {
  static const _statuses = <String?>[
    null,
    'PENDING',
    'APPROVED',
    'REJECTED',
    'EXPIRED',
  ];

  /// null = Semua, 1 = hari ini, 7 = 7 hari terakhir
  static const _dayFilters = <int?>[null, 1, 7];

  String? _status;
  int? _days;
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

  bool _match(Map<String, dynamic> item) {
    if (_status != null &&
        (item['status'] as String?)?.toUpperCase() != _status) {
      return false;
    }
    if (_days != null) {
      final created =
          DateTime.tryParse((item['created_at'] as String?) ?? '')?.toLocal();
      if (created == null) return false;
      final now = DateTime.now();
      final start = _days == 1
          ? DateTime(now.year, now.month, now.day)
          : now.subtract(const Duration(days: 7));
      if (created.isBefore(start)) return false;
    }
    return true;
  }

  static String _dayLabel(int? days) {
    if (days == null) return 'Semua tanggal';
    if (days == 1) return 'Hari ini';
    return '7 hari';
  }

  /// Ekspor baris yang sedang tampil (setelah filter status/tanggal).
  Future<void> _eksporSetoran(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) {
      _pesan('Tidak ada data untuk diekspor');
      return;
    }
    final terunduh = await simpanCsv(
      'rekap-setoran-${_capWaktu()}.csv',
      bangunCsvSetoran(data),
    );
    if (!mounted) return;
    _pesan(terunduh ? 'CSV diunduh' : 'CSV disalin ke papan klip');
  }

  Future<void> _eksporPenarikan() async {
    List<WithdrawalModel> data;
    try {
      data = await ref.read(adminWithdrawalsProvider(null).future);
    } catch (_) {
      if (!mounted) return;
      _pesan('Gagal memuat data penarikan');
      return;
    }
    if (data.isEmpty) {
      _pesan('Tidak ada data untuk diekspor');
      return;
    }
    final terunduh = await simpanCsv(
      'rekap-penarikan-${_capWaktu()}.csv',
      bangunCsvPenarikan(data),
    );
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
    ref.read(adminFilterProvider.notifier).update(
          (f) => f.copyWith(query: ''),
        );
  }

  void _resetFilters() {
    setState(() {
      _status = null;
      _days = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(adminTransactionsProvider);
    final filter = ref.watch(adminFilterProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WidthLimit(
              child: HeroHeader(
                title: 'Riwayat Penyetoran',
                subtitle: 'Semua setoran dan statusnya',
                trailing: PopupMenuButton<String>(
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
                    if (jenis == 'penarikan') {
                      _eksporPenarikan();
                      return;
                    }
                    final semua =
                        ref.read(adminTransactionsProvider).valueOrNull ??
                            const [];
                    _eksporSetoran(semua.where(_match).toList());
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
                ),
              ),
            ),
            Expanded(
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _searchField(showClear: filter.query.isNotEmpty),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: _touchTarget,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _dayFilters.length + _statuses.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => _filterChip(index),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: txState.when(
                        data: (all) {
                          final list = all.where(_match).toList();
                          if (list.isEmpty) {
                            return _centeredState(
                              _EmptyState(
                                searching: filter.query.trim().isNotEmpty,
                                hasFilter: _status != null || _days != null,
                                onClearQuery: _clearQuery,
                                onResetFilters: _resetFilters,
                                onReload: () {
                                  ref.invalidate(
                                    adminTransactionsProvider,
                                  );
                                },
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: EdgeInsets.only(
                              bottom: 96 + bottomInset,
                            ),
                            itemCount: list.length,
                            itemBuilder: (context, index) =>
                                _historyRow(list[index]),
                          );
                        },
                        loading: () => _centeredState(const _LoadingCard()),
                        error: (_, __) => _centeredState(
                          _StateCard(
                            icon: Icons.cloud_off_rounded,
                            title: 'Riwayat gagal dimuat',
                            message: 'Periksa koneksi Anda, lalu muat '
                                'ulang riwayat.',
                            actionLabel: 'Coba lagi',
                            onAction: () {
                              ref.invalidate(adminTransactionsProvider);
                            },
                          ),
                        ),
                      ),
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

  /// Keadaan pendek diletakkan di tengah dengan lebar baca terbatas.
  Widget _centeredState(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: child,
      ),
    );
  }

  Widget _filterChip(int index) {
    final isDayChip = index < _dayFilters.length;
    final String label;
    final bool isSelected;

    if (isDayChip) {
      final days = _dayFilters[index];
      label = _dayLabel(days);
      isSelected = _days == days;
    } else {
      final status = _statuses[index - _dayFilters.length];
      label = status == null
          ? 'Semua status'
          : TransactionStatusHelper.toDisplayLabel(status);
      isSelected = _status == status;
    }

    return _FilterChip(
      label: label,
      selected: isSelected,
      onTap: () {
        setState(() {
          if (isDayChip) {
            _days = _dayFilters[index];
          } else {
            _status = _statuses[index - _dayFilters.length];
          }
        });
      },
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

  /// Satu baris riwayat: `TxListItem` (kolom kanan tidak terpotong) dengan
  /// catatan nama mahasiswa dan aksi validasi di bawahnya.
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
    final isPending = status.toUpperCase() == 'PENDING';
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
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (isPending) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: _touchTarget,
                  child: OutlinedButton.icon(
                    onPressed: () => VerificationBottomSheet.show(
                      context,
                      transactionData: item,
                      onVerificationComplete: () {
                        ref.invalidate(adminMetricsProvider);
                        ref.invalidate(adminTransactionsProvider);
                      },
                    ),
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: const Text('Validasi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryMain,
                      side: const BorderSide(color: AppColors.borderLine),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (reason.isNotEmpty)
          SurfaceCard(
            margin: const EdgeInsets.only(bottom: 12),
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
      ],
    );
  }
}

// --------------------------------------------------------------------- Widget

/// Batas lebar 1120 px agar hero sejajar dengan daftar di desktop (§4).
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

/// Keadaan kosong: ikon, satu kalimat, satu aksi yang relevan (§6).
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searching,
    required this.hasFilter,
    required this.onClearQuery,
    required this.onResetFilters,
    required this.onReload,
  });

  final bool searching;
  final bool hasFilter;
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
        icon: Icons.receipt_long_rounded,
        title: 'Belum ada riwayat',
        message: 'Setoran mahasiswa akan tampil di sini setelah dikirim.',
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
              'Memuat riwayat...',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
