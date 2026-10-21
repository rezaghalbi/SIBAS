import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/status_helper.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../verification/presentation/providers/verification_provider.dart';
import '../../../verification/presentation/widgets/verification_bottom_sheet.dart';

/// Riwayat seluruh penyetoran (semua status) untuk Admin,
/// dengan filter status & rentang tanggal sesuai prd.md.
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

  String? _status;
  DateTimeRange? _range;

  bool _match(Map<String, dynamic> item) {
    if (_status != null &&
        (item['status'] as String?)?.toUpperCase() != _status) {
      return false;
    }
    if (_range != null) {
      final created = DateTime.tryParse((item['created_at'] as String?) ?? '');
      if (created == null) return false;
      final end = _range!.end.add(const Duration(days: 1));
      if (created.isBefore(_range!.start) || !created.isBefore(end)) return false;
    }
    return true;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(adminTransactionsProvider);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Riwayat Penyetoran'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _statuses.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == _statuses.length) {
                    final label = _range == null
                        ? 'Rentang Tanggal'
                        : '${DateFormat('dd/MM/yy').format(_range!.start)} - '
                            '${DateFormat('dd/MM/yy').format(_range!.end)}';
                    return ActionChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 16),
                      label: Text(label),
                      backgroundColor: AppColors.cardSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.borderLine),
                      ),
                      onPressed: _range == null
                          ? _pickRange
                          : () => setState(() => _range = null),
                    );
                  }

                  final status = _statuses[index];
                  final isSelected = _status == status;
                  return ChoiceChip(
                    label: Text(
                      status == null
                          ? 'Semua'
                          : TransactionStatusHelper.toDisplayLabel(status),
                    ),
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
                        color: isSelected
                            ? AppColors.primaryMain
                            : AppColors.borderLine,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _status = status);
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: txState.when(
                data: (all) {
                  final list = all.where(_match).toList();
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        'Belum ada riwayat penyetoran pada filter ini.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final profile = item['profiles'] as Map<String, dynamic>?;
                      final category = item['trash_types'] as Map<String, dynamic>?;
                      final name = (profile?['full_name'] as String?) ?? 'Mahasiswa';
                      final nim = (profile?['nim'] as String?) ?? '-';
                      final catName = (category?['name'] as String?) ?? 'Sampah';
                      final weight = (item['weight'] != null)
                          ? (item['weight'] as num).toDouble()
                          : 0.0;
                      final amount =
                          item['final_amount'] ?? item['estimated_amount'];
                      final status = (item['status'] as String?) ?? 'PENDING';
                      final created = DateTime.tryParse(
                          (item['created_at'] as String?) ?? '');
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
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.mintSoftBackground,
                            child: Icon(Icons.recycling_rounded,
                                color: AppColors.primaryMain),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              StatusBadge(status: status),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'NIM: $nim • $catName',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${weight.toStringAsFixed(1)} kg'
                                '${amount != null ? ' • ${currency.format(amount)}' : ''}'
                                '${created != null ? ' • ${dateFormat.format(created)}' : ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark),
                              ),
                              if (item['rejection_reason'] != null)
                                Text(
                                  'Alasan: ${item['rejection_reason']}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.danger),
                                ),
                            ],
                          ),
                          trailing: isPending
                              ? TextButton(
                                  onPressed: () => VerificationBottomSheet.show(
                                    context,
                                    transactionData: item,
                                    onVerificationComplete: () {
                                      ref.invalidate(adminMetricsProvider);
                                      ref.invalidate(adminTransactionsProvider);
                                    },
                                  ),
                                  child: const Text('Validasi'),
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal memuat riwayat: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}