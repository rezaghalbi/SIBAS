import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'glass_panel.dart';

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

  static const _studentItems = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'Beranda'),
    (icon: Icons.recycling_rounded, label: 'Setor'),
    (icon: Icons.account_balance_wallet_outlined, label: 'Tarik'),
    (icon: Icons.history_rounded, label: 'Riwayat'),
    (icon: Icons.person_outline_rounded, label: 'Profil'),
  ];

  static const _adminItems = <({IconData icon, String label})>[
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.fact_check_outlined, label: 'Pengajuan'),
    (icon: Icons.qr_code_scanner_rounded, label: 'Pindai'),
    (icon: Icons.history_rounded, label: 'Riwayat'),
    (icon: Icons.category_rounded, label: 'Kelola'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = isAdmin ? _adminItems : _studentItems;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 2),
      child: GlassPanel(
        radius: 24,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                      badgeCount: isAdmin && index == 1 ? pendingCount : 0,
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
    final color = isActive ? AppColors.primaryMain : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 26,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: color),
                  if (badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: AppColors.statusPendingBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.statusPendingText,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.statusPendingText,
                          ),
                        ),
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
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: -0.2,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
