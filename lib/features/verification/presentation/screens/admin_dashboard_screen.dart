import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../info/presentation/providers/app_settings_provider.dart';
import '../../../students/presentation/providers/student_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(currentUserProvider);
    final metricsState = ref.watch(adminMetricsProvider);
    final txListState = ref.watch(adminTransactionsProvider);

    final adminName = userState.valueOrNull?.fullName ?? 'Petugas SIBAS';

    // Pintasan memakai data yang sudah ada; saat memuat/gagal tampilkan "—"
    // supaya kartu tetap bisa diketuk.
    final metrics = metricsState.valueOrNull;
    final studentCount = ref.watch(studentsProvider).valueOrNull?.length;
    final qrTtlMinutes =
        ref.watch(appSettingsProvider).valueOrNull?.qrTtlMinutes;

    final pendingLabel =
        metrics == null ? '—' : '${metrics.pendingCount} transaksi menunggu';
    final historyLabel = metrics == null
        ? '—'
        : '${metrics.approvedCount} disetujui · '
            '${metrics.rejectedCount} ditolak';
    final studentsLabel =
        studentCount == null ? '—' : '$studentCount mahasiswa';
    final settingsLabel = qrTtlMinutes == null ? '—' : 'QR $qrTtlMinutes menit';
    // Total berat tetap ditampilkan sebagai keterangan judul seksi.
    final weightLabel = metrics == null
        ? 'Total — kg'
        : 'Total ${metrics.totalWeightKg.toStringAsFixed(1)} kg';

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

          // 2. Ringkasan & pintasan cepat
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ringkasan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    weightLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              // 360 px → 2 kolom; desktop → tepat 4 kolom selebar konten, tanpa
              // slot kosong saat lebar jendela berubah.
              final columns = constraints.crossAxisExtent < 700 ? 2 : 4;
              const gap = 12.0;
              final available = constraints.crossAxisExtent - 40;
              final extent = (available - gap * (columns - 1)) / columns;

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: extent,
                    mainAxisExtent: 108,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                  ),
                  delegate: SliverChildListDelegate([
                    _DashboardShortcutTile(
                      title: 'Menunggu Validasi',
                      value: pendingLabel,
                      icon: Icons.pending_actions_rounded,
                      iconColor: AppColors.statusPendingText,
                      iconBackground: AppColors.statusPendingBg,
                      onTap: () => context.push('/admin/submissions'),
                    ),
                    _DashboardShortcutTile(
                      title: 'Riwayat Transaksi',
                      value: historyLabel,
                      icon: Icons.history_rounded,
                      iconColor: AppColors.statusApprovedText,
                      iconBackground: AppColors.statusApprovedBg,
                      onTap: () => context.push('/admin/history'),
                    ),
                    _DashboardShortcutTile(
                      title: 'Data Mahasiswa',
                      value: studentsLabel,
                      icon: Icons.groups_rounded,
                      iconColor: AppColors.primaryMain,
                      iconBackground: AppColors.mintSoftBackground,
                      onTap: () => context.push('/admin/students'),
                    ),
                    _DashboardShortcutTile(
                      title: 'Pengaturan',
                      value: settingsLabel,
                      icon: Icons.tune_rounded,
                      iconColor: AppColors.textMuted,
                      iconBackground: AppColors.mintSoftBackground,
                      onTap: () => context.push('/admin/settings'),
                    ),
                  ]),
                ),
              );
            },
          ),

          // Pintasan pengelolaan jenis sampah & tarif
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            sliver: SliverToBoxAdapter(
              child: GlassPanel(
                radius: 18,
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: () => context.push('/admin/trash-types'),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.mintSoftBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.category_rounded, size: 18, color: AppColors.primaryMain),
                    ),
                    title: const Text(
                      'Kelola Jenis Sampah',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Atur kategori dan tarif per kg',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
                  ),
                ),
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
                      ref.invalidate(studentsProvider);
                      ref.invalidate(appSettingsProvider);
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
                      final category = item['trash_types'] as Map<String, dynamic>?;

                      final name = (profile?['full_name'] as String?) ?? 'Mahasiswa';
                      final nim = (profile?['nim'] as String?) ?? '-';
                      final catName = (category?['name'] as String?) ?? (item['category_name'] as String?) ?? 'Sampah';
                      final weight = (item['weight'] != null) ? (item['weight'] as num).toDouble() : 0.0;
                      final status = (item['status'] as String?) ?? 'PENDING';
                      final isPending = status.toUpperCase() == 'PENDING';
                      final id = item['id'] as String?;
                      final canOpen = id != null && id.isNotEmpty;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLine),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          onTap: canOpen
                              ? () => context.push('/transaction/$id')
                              : null,
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

/// Kartu pintasan dashboard admin: seluruh permukaan kartu adalah target
/// sentuh (tinggi 108 px, jauh di atas minimum 44 px).
class _DashboardShortcutTile extends StatelessWidget {
  const _DashboardShortcutTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: _radius,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: _radius,
          border: Border.all(color: AppColors.borderLine),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: _radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                // `scaleDown` menjaga angka panjang tetap satu baris di layar
                // 360 px tanpa memotong informasi.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

