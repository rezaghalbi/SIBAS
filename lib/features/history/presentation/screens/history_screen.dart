import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
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
            // Filter Status Chips Horisontal
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = _selectedFilter == filter;

                  return ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppColors.primaryMain,
                    backgroundColor: AppColors.cardSurface,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryMain : AppColors.borderLine,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                  );
                },
              ),
            ),

            // Daftar Riwayat Transaksi
            Expanded(
              child: historyState.when(
                data: (transactions) {
                  final filtered = transactions.where(_matchesFilter).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final tx = filtered[index];
                      return TxListItem(
                        categoryName: tx.categoryName,
                        weightKg: tx.weight,
                        amountRp: tx.finalAmount ?? tx.estimatedAmount,
                        status: tx.status,
                        createdAt: tx.createdAt,
                        onTap: () => context.push('/qr/${tx.id}'),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Gagal memuat riwayat: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
