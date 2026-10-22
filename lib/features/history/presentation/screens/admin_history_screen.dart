import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/status_helper.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../verification/data/csv_export.dart';
import '../../../verification/data/csv_download_stub.dart'
    if (dart.library.js_interop) '../../../verification/data/csv_download_web.dart';
import '../../../verification/presentation/providers/verification_provider.dart';
import '../../../verification/presentation/widgets/verification_bottom_sheet.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';

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
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Ekspor CSV',
            icon: const Icon(Icons.download_rounded),
            onSelected: (jenis) {
              if (jenis == 'penarikan') {
                _eksporPenarikan();
                return;
              }
              final semua =
                  ref.read(adminTransactionsProvider).valueOrNull ?? const [];
              _eksporSetoran(semua.where(_match).toList());
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'setoran', child: Text('Rekap setoran')),
              PopupMenuItem(value: 'penarikan', child: Text('Rekap penarikan')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _dayFilters.length + _statuses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isDayChip = index < _dayFilters.length;
                  String label;
                  bool isSelected;
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

                  return ChoiceChip(
                    label: Text(label),
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
                      if (!selected) return;
                      setState(() {
                        if (isDayChip) {
                          _days = _dayFilters[index];
                        } else {
                          _status = _statuses[index - _dayFilters.length];
                        }
                      });
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
                          // Admin boleh membuka detail untuk melihat verifikator & alasan.
                          onTap: () => context.push('/transaction/${item['id']}'),

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