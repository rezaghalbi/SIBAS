import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/verification_provider.dart';
import '../widgets/verification_bottom_sheet.dart';

/// Halaman Dashboard Utama Petugas Admin
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(currentUserProvider);
    final metricsState = ref.watch(adminMetricsProvider);
    final txListState = ref.watch(adminTransactionsProvider);

    final adminName = userState.valueOrNull?.fullName ?? 'Petugas SIBAS';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 1. Hero Header
          SliverToBoxAdapter(
            child: HeroHeader(
              title: 'Halo, $adminName',
              subtitle: 'Panel Validasi & Pengelolaan Bank Sampah',
              trailing: IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Text('Keluar Akun Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                      content: const Text('Apakah Anda yakin ingin keluar dari panel admin?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.read(currentUserProvider.notifier).logout();
                          },
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                ),
              ),
              bottomContent: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.heroCardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.heroCardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mode Petugas', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('Pemindai QR Siap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/admin/scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text('Buka Pemindai QR', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Metrik Statistik
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: metricsState.when(
                data: (metrics) => GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _buildMetricCard(
                      title: 'Total Sampah',
                      value: '${metrics.totalWeightKg.toStringAsFixed(1)} kg',
                      icon: Icons.scale_rounded,
                      iconColor: AppColors.primaryMain,
                      bgColor: AppColors.mintSoftBackground,
                    ),
                    _buildMetricCard(
                      title: 'Pending Validasi',
                      value: '${metrics.pendingCount} Transaksi',
                      icon: Icons.pending_actions_rounded,
                      iconColor: AppColors.statusPendingText,
                      bgColor: AppColors.statusPendingBg,
                    ),
                    _buildMetricCard(
                      title: 'Total Diterima',
                      value: '${metrics.approvedCount}',
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.statusApprovedText,
                      bgColor: AppColors.statusApprovedBg,
                    ),
                    _buildMetricCard(
                      title: 'Total Ditolak',
                      value: '${metrics.rejectedCount}',
                      icon: Icons.cancel_outlined,
                      iconColor: AppColors.statusRejectedText,
                      bgColor: AppColors.statusRejectedBg,
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Gagal memuat metrik: $e'),
              ),
            ),
          ),

          // 3. Search & Filter Bar (Nama/NIM)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
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
                    hintText: 'Cari Nama Mahasiswa, NIM, atau ID Transaksi...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primaryMain),
                  ),
                ),
              ),
            ),
          ),

          // 4. Header Daftar Transaksi
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daftar Penyetoran Mahasiswa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryMain),
                    onPressed: () {
                      ref.invalidate(adminMetricsProvider);
                      ref.invalidate(adminTransactionsProvider);
                    },
                  ),
                ],
              ),
            ),
          ),

          // 5. List Transaksi
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: txListState.when(
              data: (txList) {
                if (txList.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: AppColors.cardSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderLine)),
                      child: const Center(
                        child: Text('Belum ada transaksi yang sesuai kriteria pencarian.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = txList[index];
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
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.mintSoftBackground,
                            child: Icon(Icons.recycling_rounded, color: AppColors.primaryMain),
                          ),
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
                              Text('Berat Pengajuan: ${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                            ],
                          ),
                          trailing: isPending
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryMain,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: () {
                                    VerificationBottomSheet.show(
                                      context,
                                      transactionData: item,
                                      onVerificationComplete: () {
                                        ref.invalidate(adminMetricsProvider);
                                        ref.invalidate(adminTransactionsProvider);
                                      },
                                    );
                                  },
                                  child: const Text('Validasi'),
                                )
                              : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ),
                      );
                    },
                    childCount: txList.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))),
              error: (e, _) => SliverToBoxAdapter(child: Text('Error: $e')),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
