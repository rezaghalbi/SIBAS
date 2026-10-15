import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../verification/presentation/providers/verification_provider.dart';
import '../../../verification/presentation/widgets/verification_bottom_sheet.dart';

class AdminHistoryScreen extends ConsumerStatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  ConsumerState<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends ConsumerState<AdminHistoryScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'Semua';

  final List<String> _statusFilters = [
    'Semua',
    'Menunggu Validasi',
    'Disetujui',
    'Ditolak',
    'Kedaluwarsa',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesStatus(String statusStr) {
    if (_selectedStatus == 'Semua') return true;
    final upper = statusStr.toUpperCase();
    if (_selectedStatus == 'Menunggu Validasi') return upper == 'PENDING';
    if (_selectedStatus == 'Disetujui') return upper == 'APPROVED';
    if (_selectedStatus == 'Ditolak') return upper == 'REJECTED';
    if (_selectedStatus == 'Kedaluwarsa') return upper == 'EXPIRED';
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final txListState = ref.watch(adminTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Semua Riwayat Setoran'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin/dashboard'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLine),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(adminFilterProvider.notifier).update((f) => f.copyWith(query: val));
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Cari Nama, NIM, atau ID Transaksi...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primaryMain),
                  ),
                ),
              ),
            ),

            // Horizontal Filter Chips
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _statusFilters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _statusFilters[index];
                  final isSelected = _selectedStatus == filter;

                  return ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppColors.primaryMain,
                    backgroundColor: AppColors.cardSurface,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryMain : AppColors.borderLine,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatus = filter);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Transaksi List
            Expanded(
              child: txListState.when(
                data: (list) {
                  final filtered = list.where((item) {
                    final status = (item['status'] as String?) ?? 'PENDING';
                    return _matchesStatus(status);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Tidak ada transaksi yang cocok.', style: TextStyle(color: AppColors.textMuted)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final profile = item['profiles'] as Map<String, dynamic>?;
                      final category = item['waste_categories'] as Map<String, dynamic>?;

                      final name = (profile?['full_name'] as String?) ?? 'Mahasiswa';
                      final nim = (profile?['nim'] as String?) ?? '-';
                      final catName = (category?['name'] as String?) ?? (item['category_name'] as String?) ?? 'Sampah';
                      final weight = (item['weight'] != null) ? (item['weight'] as num).toDouble() : 0.0;
                      final status = (item['status'] as String?) ?? 'PENDING';
                      final isPending = status.toUpperCase() == 'PENDING';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLine),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              StatusBadge(status: status),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('NIM: $nim • $catName', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              const SizedBox(height: 2),
                              Text('Berat: ${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                            ],
                          ),
                          trailing: isPending
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryMain,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: () {
                                    VerificationBottomSheet.show(
                                      context,
                                      transactionData: item,
                                      onVerificationComplete: () {
                                        ref.refresh(adminTransactionsProvider);
                                      },
                                    );
                                  },
                                  child: const Text('Validasi'),
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
