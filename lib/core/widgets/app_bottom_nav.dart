import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'glass_panel.dart';

/// Satu tab navigasi SIBAS: ikon dan label.
///
/// Daftar ini dipakai bersama oleh [AppBottomNav] (layar <900 px) dan rail
/// samping di `adaptive_shell.dart` (layar ≥900 px), supaya urutan tab tidak
/// pernah berbeda antar tata letak.
@immutable
class AppNavItem {
  const AppNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  /// Indeks item "Pengajuan" pada [admin]: satu-satunya item berbadge.
  static const int adminPendingIndex = 1;

  static const List<AppNavItem> student = <AppNavItem>[
    AppNavItem(icon: Icons.home_rounded, label: 'Beranda'),
    AppNavItem(icon: Icons.recycling_rounded, label: 'Setor'),
    AppNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Tarik'),
    AppNavItem(icon: Icons.history_rounded, label: 'Riwayat'),
    AppNavItem(icon: Icons.person_outline_rounded, label: 'Profil'),
  ];

  static const List<AppNavItem> admin = <AppNavItem>[
    AppNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    AppNavItem(icon: Icons.fact_check_outlined, label: 'Pengajuan'),
    AppNavItem(icon: Icons.qr_code_scanner_rounded, label: 'Pindai'),
    AppNavItem(icon: Icons.history_rounded, label: 'Riwayat'),
    AppNavItem(icon: Icons.category_rounded, label: 'Kelola'),
  ];

  /// Item sesuai peran yang sedang masuk.
  static List<AppNavItem> forRole({required bool isAdmin}) =>
      isAdmin ? admin : student;

  /// Angka badge untuk sebuah indeks; 0 berarti badge disembunyikan.
  static int badgeFor({
    required int index,
    required bool isAdmin,
    required int pendingCount,
  }) {
    if (!isAdmin || index != adminPendingIndex || pendingCount <= 0) {
      return 0;
    }
    return pendingCount;
  }
}

/// Badge angka kecil di sisi item nav (mis. pengajuan yang menunggu).
///
/// Dipakai nav bawah dan rail agar keduanya tampil sama.
class AppNavBadge extends StatelessWidget {
  const AppNavBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final status = AppStatusColors.of(palette.brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16),
      decoration: BoxDecoration(
        color: status.pendingBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.pendingBorder, width: 1),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: status.pendingText,
        ),
      ),
    );
  }
}

/// Navigasi bawah bergaya kaca SIBAS.
///
/// Hanya menerima indeks; perpindahan halaman dilakukan pemanggil (shell rute).
/// ponytail: tanpa state internal — item statis, 5 tab per peran.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isAdmin;
  final int pendingCount;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isAdmin,
    this.pendingCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final items = AppNavItem.forRole(isAdmin: isAdmin);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 2),
      // Tone dense: nav harus tetap terbaca di atas konten apa pun (§7.2).
      child: GlassPanel(
        tone: GlassTone.dense,
        radius: 24,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _NavButton(
                      icon: items[index].icon,
                      label: items[index].label,
                      isActive: index == currentIndex,
                      badgeCount: AppNavItem.badgeFor(
                        index: index,
                        isAdmin: isAdmin,
                        pendingCount: pendingCount,
                      ),
                      onTap: () => onTap(index),
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

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = isActive ? palette.primary : palette.muted;

    return Semantics(
      button: true,
      selected: isActive,
      label: badgeCount > 0 ? '$label, $badgeCount menunggu' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pill tipis di belakang ikon+label. Positioned.fill supaya
            // layout item tidak bergeser saat state aktif berubah.
            if (isActive)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.mintWash,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lebar 40 dipusatkan agar badge tetap di dalam lebar item
                // (item ±65 px di layar 360) dan tidak menabrak tepi.
                SizedBox(
                  width: 40,
                  height: 26,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(child: Icon(icon, size: 22, color: color)),
                      if (badgeCount > 0)
                        Positioned(
                          top: -4,
                          right: 0,
                          child: ExcludeSemantics(
                            child: AppNavBadge(count: badgeCount),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: -0.2,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
