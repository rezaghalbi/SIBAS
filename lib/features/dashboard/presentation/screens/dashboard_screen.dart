import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/saldo_hero_card.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tx_list_item.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../deposit/presentation/providers/deposit_provider.dart';
import '../../../history/domain/models/transaction_model.dart';
import '../../../history/presentation/providers/transaction_provider.dart';
import '../../../notification/presentation/widgets/notification_sheet.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../../../../core/theme/sibas_colors.dart';

/// Jarak antar seksi pada skala 4 pt (§4).
const double _sectionGap = 24;

/// Lebar konten maksimal desktop (§4).
const double _maxContentWidth = 1120;

/// Radius kartu konten (r-20) dan baris ringkas (r-16) sesuai §4.
const double _cardRadius = 20;
const double _rowRadius = 16;

/// Target sentuh minimum 44 px (§4, §1 butir 6).
const double _touchTarget = 44;

/// Judul seksi Glass 2.0 (§3): 15.5 px, w700, tracking rapat.
TextStyle get _sectionTitle => TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  height: 1.25,
  color: SibasColors.text,
);

/// Angka uang, berat, dan hitungan memakai lebar digit tetap (§3).
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Halaman Dashboard Utama Mahasiswa dengan tampilan SIBAS Glass 2.0.
///
/// Sesuai §7.1, kaca hanya dipakai lapisan mengambang: satu-satunya
/// `BackdropFilter` di layar ini berasal dari panel saldo di dalam hero.
/// Kartu konten memakai `SurfaceCard` (kaca statis, tanpa blur) agar satu
/// bahasa dengan layar lain.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentUserProvider);
    final recentTxState = ref.watch(recentTransactionsProvider);

    final user = userState.valueOrNull;
    final userName = user?.fullName ?? 'Mahasiswa';
    final userNim =
        user?.nim != null ? 'NIM: ${user!.nim}' : 'Mahasiswa Poltekkes';
    final balance = user?.balance ?? 0.0;
    final totalWeight = user?.totalWeight ?? 0.0;

    // Rupiah hanya ditampilkan bila ada jenis sampah dengan tarif > 0.
    final categoriesState = ref.watch(wasteCategoriesProvider);
    final hasActiveRate =
        categoriesState.valueOrNull?.any((item) => item.pricePerKg > 0) ??
            false;

    final pendingCount = recentTxState.valueOrNull
            ?.where((tx) => tx.status.toUpperCase() == 'PENDING')
            .length ??
        0;

    // Penarikan pending ikut menambah badge lonceng.
    final pendingWithdrawalCount = ref
            .watch(studentWithdrawalsProvider)
            .valueOrNull
            ?.where((item) => item.isPending)
            .length ??
        0;
    final notificationCount = pendingCount + pendingWithdrawalCount;

    // Nav mengambang tidak boleh menutup kartu terakhir (§4).
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SibasColors.background,
      body: CustomScrollView(
        slivers: [
          // 1. Hero header, panel saldo, dan aksi setor.
          SliverToBoxAdapter(
            child: _WidthLimit(
              child: HeroHeader(
                title: 'Halo, $userName',
                subtitle: userNim,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Notifikasi',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: _touchTarget,
                        minHeight: _touchTarget,
                      ),
                      onPressed: () => showNotificationSheet(context),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          if (notificationCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                constraints: const BoxConstraints(minWidth: 16),
                                decoration: BoxDecoration(
                                  color: SibasColors.status.pendingBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: SibasColors.status.pendingText,
                                  ),
                                ),
                                child: Text(
                                  notificationCount > 9
                                      ? '9+'
                                      : '$notificationCount',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: SibasColors.status.pendingText,
                                    fontFeatures: _tabular,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Keluar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: _touchTarget,
                        minHeight: _touchTarget,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text(
                              'Keluar Aplikasi',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            content: const Text(
                              'Apakah Anda yakin ingin keluar dari akun SIBAS?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: SibasColors.muted,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SibasColors.status.badText,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ref
                                      .read(currentUserProvider.notifier)
                                      .logout();
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
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                bottomContent: GestureDetector(
                  onTap: () => context.push('/saldo'),
                  child: SaldoHeroCard(
                    balance: balance,
                    totalWeightKg: totalWeight,
                    hasActiveRate: hasActiveRate,
                    onSetorPressed: () => context.push('/setor'),
                  ),
                ),
              ),
            ),
          ),

          // 2. Ringkasan pengajuan menunggu verifikasi.
          if (pendingCount > 0)
            SliverToBoxAdapter(
              child: _Section(
                child: _PendingBanner(
                  count: pendingCount,
                  onTap: () => context.push('/history'),
                ),
              ),
            ),

          // 3. Aktivitas setor terakhir.
          recentTxState.when(
            data: (transactions) => SliverToBoxAdapter(
              child: _Section(
                child: _ActivitySection(
                  items: transactions,
                  onSeeAll: () => context.push('/history'),
                  onOpen: (tx) => context.push('/qr/${tx.id}'),
                ),
              ),
            ),
            loading: () => const SliverToBoxAdapter(
              child: _Section(
                child: SurfaceCard(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: _Section(
                child: SurfaceCard(
                  color: SibasColors.status.rejectedBackground,
                  child: Text(
                    'Gagal memuat aktivitas: $err',
                    style: TextStyle(
                      fontSize: 13,
                      color: SibasColors.status.badText,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Ruang bawah 96 px + safe area agar nav tidak menutup konten.
          SliverToBoxAdapter(
            child: SizedBox(height: 96 + bottomInset),
          ),
        ],
      ),
    );
  }
}

/// Pembungkus seksi: lebar konten maksimal 1120 px dengan gutter 16/32 (§4).
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.only(top: _sectionGap),
        child: child,
      ),
    );
  }
}

/// Batas lebar yang sama untuk hero, agar tepi kartu sejajar dengan seksi.
class _WidthLimit extends StatelessWidget {
  const _WidthLimit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );
  }
}

/// Baris ringkas menuju riwayat saat ada pengajuan menunggu.
///
/// Panel status memakai `SurfaceCard` berwarna `statusPendingBg` supaya
/// border, highlight, dan sudutnya mengikuti resep yang sama dengan kartu
/// konten lain.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: _rowRadius,
      color: SibasColors.status.pendingBackground,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_rowRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_rowRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    // Chip ikon di atas panel amber: putih tipis agar ikon
                    // tetap terbaca tanpa warna baru.
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 18,
                    color: SibasColors.status.pendingText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count pengajuan menunggu verifikasi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SibasColors.text,
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: SibasColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Judul seksi dan daftar transaksi terakhir dalam satu panel pengelompok.
///
/// Baris transaksi (`TxListItem`) sudah berupa kartu solid, jadi panel
/// pembungkusnya memakai tone `subtle`: tidak ada kartu di dalam kartu yang
/// bertumpuk putih.
class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.items,
    required this.onSeeAll,
    required this.onOpen,
  });

  final List<TransactionModel> items;
  final VoidCallback onSeeAll;
  final void Function(TransactionModel) onOpen;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      tone: SurfaceTone.subtle,
      radius: _cardRadius,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Aktivitas Setor Terakhir',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _sectionTitle,
                  ),
                ),
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: SibasColors.leaf,
                    minimumSize: const Size(0, _touchTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            const _EmptyActivity()
          else
            for (final tx in items)
              TxListItem(
                categoryName: tx.categoryName,
                weightKg: tx.weight,
                amountRp: tx.finalAmount ?? tx.estimatedAmount,
                status: tx.status,
                createdAt: tx.createdAt,
                onTap: () => onOpen(tx),
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
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: SibasColors.mintWash,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: SibasColors.leaf,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text('Belum Ada Setoran', style: _sectionTitle),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Kumpulkan sampah daur ulang Anda dan mulailah setor untuk '
              'tabungan lingkungan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: SibasColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
