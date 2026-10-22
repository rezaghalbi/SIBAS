import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/tx_list_item.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../../domain/models/transaction_model.dart';

/// Provider seluruh riwayat transaksi mahasiswa (limit 100)
final allStudentTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
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
    await ref.refresh(allStudentTransactionsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(allStudentTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Setoran Saya'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Status Chips di atas panel kaca
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: GlassPanel(
                radius: 18,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _filters.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;

                      return Center(
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          selectedColor: AppColors.primaryMain,
                          backgroundColor: Colors.white.withValues(alpha: 0.30),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primaryMain
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Daftar Riwayat Transaksi
            Expanded(
              child: historyState.when(
                data: (transactions) {
                  final filtered = transactions.where(_matchesFilter).toList();

                  if (filtered.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      color: AppColors.primaryMain,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          const SizedBox(height: 110),
                          Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: AppColors.mintSoftBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.folder_open_rounded,
                                  size: 32,
                                  color: AppColors.primaryMain,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Tidak ada setoran dengan status "$_selectedFilter"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.primaryMain,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        return TxListItem(
                          categoryName: tx.categoryName,
                          weightKg: tx.weight,
                          amountRp: tx.finalAmount ?? tx.estimatedAmount,
                          status: tx.status,
                          createdAt: tx.createdAt,
                          onTap: () => context.push('/transaction/${tx.id}'),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primaryMain,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 110),
                      Center(child: Text('Gagal memuat riwayat: $err')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
