import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tx_list_item.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
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

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedFilter = 'Semua';

  final List<String> _filters = [
    'Semua',
    'Menunggu Verifikasi',
    'Disetujui',
    'Ditolak',
    'Kedaluwarsa',
  ];

  bool _matchesFilter(TransactionModel tx) {
    if (_selectedFilter == 'Semua') return true;
    final status = tx.status.toUpperCase();
    if (_selectedFilter == 'Menunggu Verifikasi') return status == 'PENDING';
    if (_selectedFilter == 'Disetujui') return status == 'APPROVED';
    if (_selectedFilter == 'Ditolak') return status == 'REJECTED';
    if (_selectedFilter == 'Kedaluwarsa') return status == 'EXPIRED';
    return true;
  }

  Future<void> _refresh() async {
    ref.invalidate(allStudentTransactionsProvider);
    await ref.read(allStudentTransactionsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(allStudentTransactionsProvider);

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
              const SizedBox(height: 20),
              _StatusFilterBar(
                filters: _filters,
                selected: _selectedFilter,
                onSelected: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: historyState.when(
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
                        onRetry: () {
                          _refresh();
                        },
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
          'Riwayat Setoran',
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
          'Pantau status verifikasi setiap setoran sampah Anda.',
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
  const _HistoryEmpty({required this.filter, this.onResetFilter});

  final String filter;
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
              Icons.receipt_long_rounded,
              size: 30,
              color: SibasColors.leaf,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isAll ? 'Belum ada setoran' : 'Belum ada setoran "$filter"',
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
                ? 'Setoran yang Anda kirim akan muncul di sini beserta '
                    'status verifikasinya.'
                : 'Coba pilih status lain untuk melihat setoran Anda.',
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
              onPressed: () => context.go('/setor'),
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
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Setor Sampah'),
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
