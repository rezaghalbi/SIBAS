import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/theme/app_palette.dart';

/// Hub pengelolaan admin. Semua menu master data dan pengaturan masuk dari
/// sini agar tidak ada dua pintu yang menampilkan daftar yang sama.
class AdminManageScreen extends StatelessWidget {
  const AdminManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppPalette.of(context).background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: const HeroHeader(
                  title: 'Kelola',
                  subtitle: 'Atur data dan pengaturan aplikasi',
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 96 + bottomInset),
            sliver: SliverList(
              delegate: SliverChildListDelegate(const [
                _ManageTile(
                  icon: Icons.category_rounded,
                  title: 'Kelola Jenis Sampah',
                  subtitle: 'Atur jenis, tarif, dan foto',
                  route: '/admin/trash-types',
                ),
                _ManageTile(
                  icon: Icons.location_on_rounded,
                  title: 'Kelola Wilayah',
                  subtitle: 'Atur lokasi bank sampah',
                  route: '/admin/locations',
                ),
                _ManageTile(
                  icon: Icons.settings_rounded,
                  title: 'Pengaturan Aplikasi',
                  subtitle: 'Atur QR dan kontak admin',
                  route: '/admin/settings',
                ),
                _ManageTile(
                  icon: Icons.people_alt_rounded,
                  title: 'Data Mahasiswa',
                  subtitle: 'Lihat akun dan koreksi data',
                  route: '/admin/students',
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _ManageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ContentWidth(
      maxWidth: 720,
      child: SurfaceCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => context.push(route),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.mintWash,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: palette.leaf),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}
