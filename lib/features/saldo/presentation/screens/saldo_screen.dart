import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../deposit/presentation/providers/deposit_provider.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';

/// Angka uang, berat, dan tanggal memakai tabular figures (§3).
const List<FontFeature> _tabularFigures = [FontFeature.tabularFigures()];

/// Saldo tersedia, pengajuan penarikan, dan riwayat penarikan mahasiswa.
class SaldoScreen extends ConsumerWidget {
  const SaldoScreen({super.key});

  /// Kolom konten dibatasi agar nominal dan riwayat tidak melar di desktop.
  static const double _contentMaxWidth = 720;

  /// Jumlah pengajuan terakhir yang tampil di ringkasan layar.
  static const int _recentLimit = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final balanceState = ref.watch(availableBalanceProvider);
    final withdrawalsState = ref.watch(studentWithdrawalsProvider);
    final categories = ref.watch(wasteCategoriesProvider).valueOrNull;

    final withdrawals =
        withdrawalsState.valueOrNull ?? const <WithdrawalModel>[];
    final recentWithdrawals = withdrawals.take(_recentLimit).toList();
    final hasActiveRate =
        categories?.any((item) => item.pricePerKg > 0) ?? false;

    // Saldo server; selama RPC loading pakai saldo profil agar tidak
    // berkedip 0.
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _contentMaxWidth,
                  ),
                  child: HeroHeader(
                    title: 'Saldo Sampah',
                    subtitle: 'Penarikan tabungan sampah Anda',
                    trailing: const _BackButton(),
                    bottomContent: GlassPanel(
                      tone: GlassTone.hero,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showRupiah
                                ? 'Saldo Tersedia'
                                : 'Total Sampah Terkumpul',
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
                              height: 44,
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
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final withdrawButton = ElevatedButton.icon(
                                onPressed: canWithdraw
                                    ? () => context.push('/tarik')
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primaryMain,
                                  disabledBackgroundColor:
                                      Colors.white.withValues(alpha: 0.35),
                                  disabledForegroundColor:
                                      Colors.white.withValues(alpha: 0.8),
                                  elevation: 0,
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.savings_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Tarik Dana',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );

                              final historyButton = OutlinedButton.icon(
                                onPressed: () => context.push('/history'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Riwayat Setoran',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );

                              // Layar 360 px: tombol ditumpuk agar label
                              // tidak terpotong; mulai 380 px berdampingan.
                              if (constraints.maxWidth < 380) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    withdrawButton,
                                    const SizedBox(height: 10),
                                    historyButton,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: withdrawButton),
                                  const SizedBox(width: 10),
                                  Expanded(child: historyButton),
                                ],
                              );
                            },
                          ),
                          if (!canWithdraw &&
                              !balanceState.isLoading &&
                              !balanceState.hasError) ...[
                            const SizedBox(height: 10),
                            Text(
                              showRupiah
                                  ? 'Penarikan bisa diajukan setelah '
                                      'ada saldo disetujui.'
                                  : 'Tarif per kg belum aktif, '
                                      'penarikan belum tersedia.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: _contentMaxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    if (hasError) ...[
                      _ErrorBox(
                        message:
                            'Gagal memuat data saldo. Periksa koneksi Anda.',
                        onRetry: () {
                          ref.invalidate(availableBalanceProvider);
                          ref.invalidate(studentWithdrawalsProvider);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    _SummaryRow(
                      totalWeightKg: totalWeight,
                      withdrawalCount: withdrawals.length,
                      showWeight: showRupiah,
                    ),
                    if (!withdrawalsState.hasError) ...[
                      const SizedBox(height: 26),
                      _SectionTitle(
                        label: 'Penarikan Terakhir',
                        trailing: withdrawals.isEmpty
                            ? null
                            : '${withdrawals.length} pengajuan',
                      ),
                      const SizedBox(height: 12),
                      ..._buildWithdrawalSection(
                        state: withdrawalsState,
                        recent: recentWithdrawals,
                        total: withdrawals.length,
                      ),
                    ],
                    SizedBox(
                      height: 24 + MediaQuery.paddingOf(context).bottom,
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

  /// Riwayat singkat: empat pengajuan terbaru, keadaan kosong, atau pemuat.
  List<Widget> _buildWithdrawalSection({
    required AsyncValue<List<WithdrawalModel>> state,
    required List<WithdrawalModel> recent,
    required int total,
  }) {
    if (state.isLoading && recent.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (recent.isEmpty) {
      return const [_EmptyWithdrawals()];
    }

    return [
      for (final withdrawal in recent)
        _WithdrawalTile(withdrawal: withdrawal),
      if (total > recent.length)
        _Footnote(
          text: 'Menampilkan ${recent.length} dari $total pengajuan '
              'terakhir.',
        ),
    ];
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
    // Ukuran display naik di layar lebar (§3), tetap muat di 360 px.
    final nominalSize = MediaQuery.sizeOf(context).width >= 600 ? 38.0 : 32.0;

    if (showRupiah) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nominal besar tidak boleh terpotong di layar 360 px.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currency.format(balance),
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: nominalSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontFeatures: _tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total kontribusi ${totalWeight.toStringAsFixed(1)} kg',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontFeatures: _tabularFigures,
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
          style: TextStyle(
            color: Colors.white,
            fontSize: nominalSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            fontFeatures: _tabularFigures,
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

/// Dua kartu ringkasan: berat terkumpul dan jumlah pengajuan penarikan.
///
/// Bila tarif belum aktif, hero sudah menampilkan berat, jadi kartu berat
/// disembunyikan agar tidak mengulang angka yang sama.
class _SummaryRow extends StatelessWidget {
  final double totalWeightKg;
  final int withdrawalCount;
  final bool showWeight;

  const _SummaryRow({
    required this.totalWeightKg,
    required this.withdrawalCount,
    required this.showWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showWeight) ...[
          Expanded(
            child: _SummaryCard(
              label: 'Berat terkumpul',
              value: totalWeightKg.toStringAsFixed(1),
              unit: 'kg',
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _SummaryCard(
            label: 'Pengajuan tarik',
            value: '$withdrawalCount',
            unit: 'kali',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary,
                      fontFeatures: _tabularFigures,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final String? trailing;

  const _SectionTitle({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
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
    final reason = withdrawal.rejectionReason;
    final hasReason = reason != null && reason.isNotEmpty;

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.mintSoftBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppColors.primaryMain,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currency.format(withdrawal.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                    fontFeatures: _tabularFigures,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date.format(withdrawal.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontFeatures: _tabularFigures,
                  ),
                ),
                // Badge di bawah tanggal: label status terpanjang tetap utuh
                // di layar 360 px.
                const SizedBox(height: 8),
                StatusBadge(status: withdrawal.status),
                if (hasReason) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SurfaceCard(
                      tone: SurfaceTone.subtle,
                      color: AppColors.statusRejectedBg,
                      radius: 16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'Alasan: $reason',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWithdrawals extends StatelessWidget {
  const _EmptyWithdrawals();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.mintSoftBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primaryMain,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum ada pengajuan penarikan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pengajuan yang Anda kirim akan muncul di sini beserta statusnya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  final String text;

  const _Footnote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Tombol kembali di atas hero: halaman ini berdiri tanpa nav bawah.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Kembali',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      },
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 20,
        ),
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
    return SurfaceCard(
      color: AppColors.statusRejectedBg,
      radius: 16,
      padding: const EdgeInsets.all(16),
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
