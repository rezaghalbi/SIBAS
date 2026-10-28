import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../info/presentation/providers/app_settings_provider.dart';
import '../../../students/presentation/providers/student_provider.dart';
import '../../domain/models/admin_metrics_model.dart';
import '../providers/verification_provider.dart';
import '../../../../core/theme/sibas_colors.dart';

/// Halaman Dashboard Utama Petugas Admin
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(currentUserProvider);
    final metricsState = ref.watch(adminMetricsProvider);
    final txListState = ref.watch(adminRecentTransactionsProvider);

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
      backgroundColor: SibasColors.background,
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
                          child: Text('Batal', style: TextStyle(color: SibasColors.muted)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: SibasColors.status.badText, foregroundColor: Colors.white),
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
                  color: SibasColors.glassTop,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SibasColors.glassBorder),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Panel hero sempit di ponsel: tombol turun ke bawah
                    // supaya tidak bertumpuk dengan teks (§8).
                    final sempit = constraints.maxWidth < 340;

                    const info = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mode Petugas',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pemindai QR Siap',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );

                    final tombol = ElevatedButton.icon(
                      onPressed: () => context.push('/admin/scan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: SibasColors.primary,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text(
                        'Buka Pemindai QR',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );

                    if (sempit) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          info,
                          const SizedBox(height: 12),
                          tombol,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: info),
                        const SizedBox(width: 12),
                        tombol,
                      ],
                    );
                  },
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
                        color: SibasColors.text,
                      ),
                    ),
                  ),
                  Text(
                    weightLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SibasColors.primary,
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
                      iconColor: SibasColors.status.pendingText,
                      iconBackground: SibasColors.status.pendingBackground,
                      onTap: () => context.push('/admin/submissions'),
                    ),
                    _DashboardShortcutTile(
                      title: 'Riwayat Transaksi',
                      value: historyLabel,
                      icon: Icons.history_rounded,
                      iconColor: SibasColors.status.approvedText,
                      iconBackground: SibasColors.status.approvedBackground,
                      onTap: () => context.push('/admin/history'),
                    ),
                    _DashboardShortcutTile(
                      title: 'Data Mahasiswa',
                      value: studentsLabel,
                      icon: Icons.groups_rounded,
                      iconColor: SibasColors.leaf,
                      iconBackground: SibasColors.mintWash,
                      onTap: () => context.push('/admin/students'),
                    ),
                    _DashboardShortcutTile(
                      title: 'Pengaturan',
                      value: settingsLabel,
                      icon: Icons.tune_rounded,
                      iconColor: SibasColors.muted,
                      iconBackground: SibasColors.mintWash,
                      onTap: () => context.push('/admin/settings'),
                    ),
                  ]),
                ),
              );
            },
          ),

          // Rekap per lokasi bank sampah + filter cepat.
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            sliver: SliverToBoxAdapter(
              child: ContentWidth(child: _LocationRecap()),
            ),
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
                        color: SibasColors.mintWash,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.category_rounded, size: 18, color: SibasColors.leaf),
                    ),
                    title: Text(
                      'Kelola Jenis Sampah',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SibasColors.text),
                    ),
                    subtitle: Text(
                      'Atur kategori dan tarif per kg',
                      style: TextStyle(fontSize: 12, color: SibasColors.muted),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, size: 20, color: SibasColors.muted),
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
                        color: SibasColors.mintWash,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: SibasColors.leaf,
                      ),
                    ),
                    title: Text(
                      'Lokasi Bank Sampah',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SibasColors.text,
                      ),
                    ),
                    subtitle: Text(
                      'Atur titik setor dan tarik sampah',
                      style: TextStyle(
                        fontSize: 12,
                        color: SibasColors.muted,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: SibasColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Ringkasan transaksi terbaru. Arsip lengkap ada di Riwayat.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transaksi Terbaru',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SibasColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Muat ulang',
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: SibasColors.leaf,
                    ),
                    onPressed: () {
                      ref.invalidate(adminMetricsProvider);
                      ref.invalidate(adminRecentTransactionsProvider);
                      ref.invalidate(studentsProvider);
                      ref.invalidate(appSettingsProvider);
                    },
                  ),
                  TextButton(
                    onPressed: () => context.push('/admin/history'),
                    style: TextButton.styleFrom(
                      foregroundColor: SibasColors.leaf,
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text(
                      'Lihat semua',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Lima transaksi terbaru; klik untuk detail.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: txListState.when(
              data: (txList) {
                if (txList.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Belum ada transaksi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: SibasColors.muted),
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = txList[index];
                      final profile =
                          item['profiles'] as Map<String, dynamic>?;
                      final category =
                          item['trash_types'] as Map<String, dynamic>?;

                      final name =
                          (profile?['full_name'] as String?) ?? 'Mahasiswa';
                      final nim = (profile?['nim'] as String?) ?? '-';
                      final catName =
                          (category?['name'] as String?) ??
                              (item['category_name'] as String?) ??
                              'Sampah';
                      final weight = (item['weight'] != null)
                          ? (item['weight'] as num).toDouble()
                          : 0.0;
                      final status =
                          (item['status'] as String?) ?? 'PENDING';
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
                            backgroundColor: SibasColors.mintWash,
                            child: Icon(
                              Icons.recycling_rounded,
                              color: SibasColors.leaf,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SibasColors.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Berat: ${weight.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: SibasColors.primary,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: SibasColors.muted,
                          ),
                        ),
                      );
                    },
                    childCount: txList.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Text('Gagal memuat transaksi terbaru.'),
              ),
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
                      color: SibasColors.muted,
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
                    color: SibasColors.muted,
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
                      color: SibasColors.text,
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



/// Rekap setoran per lokasi bank sampah.
///
/// Mengetuk satu baris memasang filter lokasi untuk dashboard sekaligus
/// daftar pengajuan dan riwayat; "Semua lokasi" menghapus filter.
class _LocationRecap extends ConsumerWidget {
  const _LocationRecap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(adminMetricsProvider).valueOrNull;
    final lokasi = metrics?.locations ?? const <LocationMetric>[];
    final terpilih = ref.watch(adminFilterProvider).locationId;

    if (lokasi.isEmpty) return const SizedBox.shrink();

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rekap per lokasi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: SibasColors.text,
                  ),
                ),
              ),
              if (terpilih != null)
                TextButton(
                  onPressed: () => ref
                      .read(adminFilterProvider.notifier)
                      .update((f) => f.copyWith(clearLocation: true)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: SibasColors.leaf,
                  ),
                  child: const Text('Semua lokasi'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final item in lokasi)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final aktif = terpilih == item.id;
                ref.read(adminFilterProvider.notifier).update(
                      (f) => aktif
                          ? f.copyWith(clearLocation: true)
                          : f.copyWith(locationId: item.id),
                    );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      terpilih == item.id
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: terpilih == item.id
                          ? SibasColors.leaf
                          : SibasColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: SibasColors.text,
                            ),
                          ),
                          Text(
                            '${_kg(item.totalWeightKg)} kg · '
                            '${item.pendingCount} menunggu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: SibasColors.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!item.isActive)
                      Text(
                        'Nonaktif',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SibasColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _kg(double nilai) => nilai.toStringAsFixed(1);
}
