import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/saldo_hero_card.dart';
import '../../../../core/widgets/tx_list_item.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../deposit/presentation/providers/deposit_provider.dart';
import '../../../history/presentation/providers/transaction_provider.dart';

/// Halaman Dashboard Utama Mahasiswa dengan tampilan kaca SIBAS.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentUserProvider);
    final recentTxState = ref.watch(recentTransactionsProvider);

    final user = userState.valueOrNull;
    final userName = user?.fullName ?? 'Mahasiswa';
    final userNim = user?.nim != null ? 'NIM: ${user!.nim}' : 'Mahasiswa Poltekkes';
    final balance = user?.balance ?? 0.0;
    final totalWeight = user?.totalWeight ?? 0.0;

    // Rupiah hanya ditampilkan bila ada jenis sampah dengan tarif > 0.
    final categoriesState = ref.watch(wasteCategoriesProvider);
    final hasActiveRate =
        categoriesState.valueOrNull?.any((item) => item.pricePerKg > 0) ?? false;

    final pendingCount = recentTxState.valueOrNull
            ?.where((tx) => tx.status.toUpperCase() == 'PENDING')
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 1. Hero Header & Saldo Hero Card
          SliverToBoxAdapter(
            child: HeroHeader(
              title: 'Halo, $userName',
              subtitle: userNim,
              trailing: IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.w700)),
                      content: const Text('Apakah Anda yakin ingin keluar dari akun SIBAS?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                          ),
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
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                ),
              ),
              bottomContent: SaldoHeroCard(
                balance: balance,
                totalWeightKg: totalWeight,
                hasActiveRate: hasActiveRate,
                onSetorPressed: () => context.push('/setor'),
              ),
            ),
          ),

          // 2. Chip pengajuan menunggu verifikasi
          if (pendingCount > 0)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () => context.push('/history'),
                  child: GlassPanel(
                    radius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.statusPendingBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            size: 16,
                            color: AppColors.statusPendingText,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$pendingCount pengajuan menunggu verifikasi',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 3. Aktivitas setor terakhir dalam satu panel kaca
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: recentTxState.when(
              data: (transactions) {
                return SliverToBoxAdapter(
                  child: GlassPanel(
                    radius: 24,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 4, top: 6),
                              child: Text(
                                'Aktivitas Setor Terakhir',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/history'),
                              child: const Text(
                                'Lihat Semua',
                                style: TextStyle(
                                  color: AppColors.primaryMain,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (transactions.isEmpty)
                          const _EmptyActivity()
                        else
                          for (final tx in transactions)
                            TxListItem(
                              categoryName: tx.categoryName,
                              weightKg: tx.weight,
                              amountRp: tx.finalAmount ?? tx.estimatedAmount,
                              status: tx.status,
                              createdAt: tx.createdAt,
                              onTap: () => context.push('/qr/${tx.id}'),
                            ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.statusRejectedBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Gagal memuat aktivitas: $err', style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 104), // Ruang untuk bottom nav shell
          ),
        ],
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.mintSoftBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryMain, size: 32),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Setoran',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Kumpulkan sampah daur ulang Anda dan mulailah setor untuk tabungan lingkungan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
