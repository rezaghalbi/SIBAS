import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'app_bottom_nav.dart';

/// Shell navigasi adaptif SIBAS (§8, §10.6).
///
/// - `<900 px`: nav bawah mengambang, sama seperti sebelumnya.
/// - `≥900 px`: rail samping solid selebar 268 px, tanpa blur.
///
/// Scaffold berada di sini, di luar [navigationShell], supaya perpindahan tab
/// tidak ikut transisi dan state tiap tab tetap hidup.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.navigationShell,
    required this.currentIndex,
    required this.isAdmin,
    required this.pendingCount,
    required this.onTap,
  });

  /// Lebar layar tempat rail menggantikan nav bawah (§8).
  static const double breakpoint = 900;

  /// Lebar rail samping sesuai §8.
  static const double railWidth = 268;

  /// Konten tab aktif, biasanya `StatefulNavigationShell`.
  final Widget navigationShell;
  final int currentIndex;
  final bool isAdmin;
  final int pendingCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= breakpoint;

    if (!isWide) {
      // Tanpa `extendBody`: layar belum punya padding bawah 96 px, jadi body
      // akan tertutup nav jika diperpanjang ke belakangnya.
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: AppBottomNav(
          currentIndex: currentIndex,
          isAdmin: isAdmin,
          pendingCount: pendingCount,
          onTap: onTap,
        ),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: railWidth,
            child: _NavRail(
              currentIndex: currentIndex,
              isAdmin: isAdmin,
              pendingCount: pendingCount,
              onTap: onTap,
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

/// Rail samping untuk layar lebar.
///
/// Solid `surface` + border kanan, tanpa `BackdropFilter`: kaca hanya milik
/// nav bawah dan sheet (§7.1).
class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.currentIndex,
    required this.isAdmin,
    required this.pendingCount,
    required this.onTap,
  });

  final int currentIndex;
  final bool isAdmin;
  final int pendingCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final items = AppNavItem.forRole(isAdmin: isAdmin);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RailBrand(isAdmin: isAdmin),
            // Jendela pendek: item digulir di dalam rail, merek tetap di atas.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                children: [
                  for (var index = 0; index < items.length; index++)
                    _RailItem(
                      item: items[index],
                      isActive: index == currentIndex,
                      badgeCount: AppNavItem.badgeFor(
                        index: index,
                        isAdmin: isAdmin,
                        pendingCount: pendingCount,
                      ),
                      onTap: () => onTap(index),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Merek SIBAS di kepala rail, dengan penanda peran yang sedang masuk.
class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final role = isAdmin ? 'Panel Petugas' : 'Bank Sampah';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.mintWash,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Icon(Icons.eco_rounded, size: 20, color: palette.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIBAS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                    color: palette.faint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu item rail: ikon 20 px, label selalu tampil, tinggi 46 px.
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.item,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  final AppNavItem item;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = isActive ? palette.primary : palette.muted;
    final weight = isActive ? FontWeight.w700 : FontWeight.w500;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Semantics(
        button: true,
        selected: isActive,
        label: item.label,
        child: Material(
          color: isActive ? palette.mintWash : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 46,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Indikator 3 px di tepi kiri item aktif.
                  if (isActive)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 3,
                        height: 24,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 20, color: color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: weight,
                              letterSpacing: -0.1,
                              color: color,
                            ),
                          ),
                        ),
                        if (badgeCount > 0) ...[
                          const SizedBox(width: 8),
                          ExcludeSemantics(
                            child: AppNavBadge(count: badgeCount),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
