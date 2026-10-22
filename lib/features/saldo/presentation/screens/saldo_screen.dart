import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../deposit/presentation/providers/deposit_provider.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../../../withdrawal/presentation/widgets/withdraw_sheet.dart';

/// Saldo tersedia, pengajuan penarikan, dan riwayat penarikan mahasiswa.
class SaldoScreen extends ConsumerWidget {
  const SaldoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final balanceState = ref.watch(availableBalanceProvider);
    final withdrawalsState = ref.watch(studentWithdrawalsProvider);
    final categories = ref.watch(wasteCategoriesProvider).valueOrNull;

    final withdrawals = withdrawalsState.valueOrNull ?? const <WithdrawalModel>[];
    final hasActiveRate = categories?.any((item) => item.pricePerKg > 0) ?? false;

    // Saldo server; selama RPC loading pakai saldo profil agar tidak berkedip 0.
    final balance = balanceState.valueOrNull ?? user?.balance ?? 0.0;
    final totalWeight = user?.totalWeight ?? 0.0;

    // Rupiah hanya bermakna bila tarif aktif, saldo ada, atau sudah ada
    // pengajuan. Bank sampah non-komersial (tarif 0, saldo 0) cukup kg.
    final showRupiah = hasActiveRate || balance > 0 || withdrawals.isNotEmpty;
    final canWithdraw = balance > 0;

    final hasError = balanceState.hasError || withdrawalsState.hasError;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(availableBalanceProvider);
          ref.invalidate(studentWithdrawalsProvider);
          try {
            await ref.read(availableBalanceProvider.future);
          } catch (_) {
            // Error sudah tampil sebagai kartu "Coba Lagi" di layar.
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: HeroHeader(
                title: 'Saldo Sampah',
                subtitle: 'Penarikan tabungan sampah Anda',
                bottomContent: GlassPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showRupiah ? 'Saldo Tersedia' : 'Total Sampah Terkumpul',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (balanceState.isLoading && user == null)
                        const SizedBox(
                          height: 40,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        _MainValue(
                          showRupiah: showRupiah,
                          balance: balance,
                          totalWeight: totalWeight,
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: canWithdraw
                                  ? () => showWithdrawSheet(context)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryMain,
                                disabledBackgroundColor:
                                    Colors.white.withValues(alpha: 0.35),
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.8),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.savings_rounded, size: 18),
                              label: const Text(
                                'Tarik Saldo',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/history'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.receipt_long_rounded, size: 18),
                              label: const Text(
                                'Riwayat Setoran',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!canWithdraw &&
                          !balanceState.isLoading &&
                          !balanceState.hasError) ...[
                        const SizedBox(height: 10),
                        Text(
                          showRupiah
                              ? 'Penarikan bisa diajukan setelah ada saldo disetujui.'
                              : 'Tarif per kg belum aktif, penarikan belum tersedia.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (hasError)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _ErrorBox(
                    message: 'Gagal memuat data saldo. Periksa koneksi Anda.',
                    onRetry: () {
                      ref.invalidate(availableBalanceProvider);
                      ref.invalidate(studentWithdrawalsProvider);
                    },
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  'Riwayat Penarikan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            ...withdrawalsState.when<List<Widget>>(
              loading: () => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (_, __) => const [SliverToBoxAdapter(child: SizedBox.shrink())],
              data: (items) => items.isEmpty
                  ? [
                      const SliverToBoxAdapter(child: _EmptyWithdrawals()),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _WithdrawalTile(withdrawal: items[index]),
                            childCount: items.length,
                          ),
                        ),
                      ),
                    ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

/// Nilai utama kartu saldo: rupiah, atau kg bila tarif belum aktif.
class _MainValue extends StatelessWidget {
  final bool showRupiah;
  final double balance;
  final double totalWeight;

  const _MainValue({
    required this.showRupiah,
    required this.balance,
    required this.totalWeight,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (showRupiah) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currency.format(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total kontribusi ${totalWeight.toStringAsFixed(1)} kg',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          totalWeight.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'kg',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Satu baris riwayat penarikan dengan status badge.
class _WithdrawalTile extends StatelessWidget {
  final WithdrawalModel withdrawal;

  const _WithdrawalTile({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final date = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.mintSoftBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppColors.primaryMain,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currency.format(withdrawal.amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date.format(withdrawal.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                if (withdrawal.rejectionReason != null &&
                    withdrawal.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Alasan: ${withdrawal.rejectionReason}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(status: withdrawal.status),
        ],
      ),
    );
  }
}

class _EmptyWithdrawals extends StatelessWidget {
  const _EmptyWithdrawals();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.mintSoftBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primaryMain,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada pengajuan penarikan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pengajuan yang Anda kirim akan muncul di sini beserta statusnya.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
