import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_palette.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
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
    final p = AppPalette.of(context);
    final warna = AppStatusColors.of(p.brightness);

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
      backgroundColor: p.background,
      body: CustomScrollView(
        slivers: [
          // 1. Hero Header
          SliverToBoxAdapter(
            child: HeroHeader(
              title: 'Halo, $adminName',
              subtitle: 'Panel Validasi & Pengelolaan Bank Sampah',
              trailing: IconButton(
                onPressed: () {
    final p = AppPalette.of(context);
    final warna = AppStatusColors.of(p.brightness);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Text('Keluar Akun Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                      content: const Text('Apakah Anda yakin ingin keluar dari panel admin?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Batal', style: TextStyle(color: p.muted)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: warna.badText, foregroundColor: Colors.white),
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
              // Panel di dalam hero memakai token hero, bukan `SurfaceCard`:
              // `color` pada `SurfaceCard` memaksa alfa `.88` di ujung gradien
              // sehingga putih `.14` berubah menjadi putih hampir pekat dan
              // teks putih kehilangan kontras.
              bottomContent: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.glassTop,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.glassBorder),
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
                        foregroundColor: p.primary,
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
                  Expanded(
                    child: Text(
                      'Ringkasan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                  ),
                  Text(
                    weightLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
    final p = AppPalette.of(context);
    final warna = AppStatusColors.of(p.brightness);
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
                      iconColor: warna.pendingText,
                      iconBackground: warna.pendingBackground,
                      onTap: () => context.push('/admin/submissions'),
                    ),
                    _DashboardShortcutTile(
                      title: 'Riwayat Transaksi',
                      value: historyLabel,
                      icon: Icons.history_rounded,
                      iconColor: warna.approvedText,
                      iconBackground: warna.approvedBackground,
                      onTap: () => context.push('/admin/history'),
                    ),
                    _DashboardShortcutTile(
                      title: 'Data Mahasiswa',
                      value: studentsLabel,
                      icon: Icons.groups_rounded,
                      iconColor: p.leaf,
                      iconBackground: p.mintWash,
                      onTap: () => context.push('/admin/students'),
                    ),
                    _DashboardShortcutTile(
                      title: 'Pengaturan',
                      value: settingsLabel,
                      icon: Icons.tune_rounded,
                      iconColor: p.muted,
                      iconBackground: p.mintWash,
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
              child: SurfaceCard(
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: () => context.push('/admin/trash-types'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.mintWash,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.category_rounded, size: 18, color: p.leaf),
                    ),
                    title: Text(
                      'Kelola Jenis Sampah',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.text),
                    ),
                    subtitle: Text(
                      'Atur kategori dan tarif per kg',
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
                  ),
                ),
              ),
            ),
          ),

          // Pintasan pengelolaan lokasi bank sampah
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverToBoxAdapter(
              child: SurfaceCard(
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    onTap: () => context.push('/admin/locations'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.mintWash,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: p.leaf,
                      ),
                    ),
                    title: Text(
                      'Lokasi Bank Sampah',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    subtitle: Text(
                      'Atur titik setor dan tarik sampah',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.muted,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: p.muted,
                    ),
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
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    ref.read(adminFilterProvider.notifier).update((f) => f.copyWith(query: val));
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Cari Nama Mahasiswa, NIM, atau ID Transaksi...',
                    prefixIcon: Icon(Icons.search_rounded, color: p.leaf),
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
                  Text('Daftar Penyetoran Mahasiswa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: p.text)),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: p.leaf),
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
    final p = AppPalette.of(context);
                if (txList.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SurfaceCard(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Belum ada transaksi yang sesuai kriteria '
                          'pencarian.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.muted),
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
    final p = AppPalette.of(context);
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

                      return SurfaceCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          onTap: canOpen
                              ? () => context.push('/transaction/$id')
                              : null,
                          leading: CircleAvatar(
                            backgroundColor: p.mintWash,
                            child: Icon(Icons.recycling_rounded, color: p.leaf),
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
                              Text('NIM: $nim • $catName', style: TextStyle(fontSize: 12, color: p.muted)),
                              const SizedBox(height: 2),
                              Text('Berat Pengajuan: ${weight.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.primary)),
                            ],
                          ),
                          trailing: isPending
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: p.leaf,
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
                              : Icon(Icons.chevron_right_rounded, color: p.muted),
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

  static const double _radius = 20;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return SurfaceCard(
      radius: _radius,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
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
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: p.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.muted,
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: p.text,
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

