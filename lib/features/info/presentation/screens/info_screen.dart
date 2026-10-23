import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../providers/app_settings_provider.dart';
import '../../../../core/theme/sibas_colors.dart';

/// Kontak resmi unit bank sampah. Isi hanya setelah admin menetapkan nilainya;
/// jangan mengarang nomor telepon/email. String kosong otomatis tampil
/// sebagai "Belum diatur".
const String _adminPhone = '+62 813-8902-1668';

/// Nomor mentah untuk aksi salin (tanpa spasi dan tanda hubung).
const String _adminPhoneRaw = '081389021668';

const String _responseNote =
    'Pengaduan ditanggapi maksimal 1×24 jam pada hari kerja';

/// Lebar konten halaman informasi. Lebih sempit dari 1120 px (§4) agar baris
/// teks tetap nyaman dibaca di desktop dengan rail.
const double _maxContentWidth = 720;

/// Jarak antar seksi pada skala 4 pt (§4).
const double _sectionGap = 24;

/// Radius kartu konten (r-20) sesuai §4.
const double _cardRadius = 20;

/// Target sentuh minimum 44 px (§1 butir 6, §4).
const double _touchTarget = 44;

/// Judul seksi Glass 2.0 (§3): 15.5 px, w700, tracking rapat.
TextStyle get _sectionTitle => TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  height: 1.25,
  color: SibasColors.text,
);

/// Label baris sebagai metadata kecil (§3), bukan teks utama.
TextStyle get _rowLabel => TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.1,
  height: 1.4,
  color: SibasColors.muted,
);

/// Angka pada nomor telepon dan langkah memakai lebar digit tetap (§3).
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Pusat informasi statis: kontak admin, jam layanan, dan alur pengaduan.
///
/// Hanya `SurfaceCard` (kaca statis, tanpa blur): tidak ada lapisan
/// mengambang di layar ini, jadi kartu tidak menambah `BackdropFilter`.
class InfoScreen extends ConsumerWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(appSettingsProvider);

    // Saat memuat atau gagal, nilai tampil "Belum diatur" — bukan karangan.
    final settings = settingsState.valueOrNull;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SibasColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _WidthLimit(
              child: HeroHeader(
                title: 'Pusat Informasi',
                subtitle: 'Kontak admin & pengaduan',
                mark: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/sibas-logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Kembali',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: _touchTarget,
                    minHeight: _touchTarget,
                  ),
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
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ContentSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Memuat atau gagal: jelaskan keadaannya, jangan tampilkan
                  // pesan galat mentah. Nilai kontak tetap "Belum diatur".
                  if (settingsState.isLoading)
                    const _SettingsNotice.loading()
                  else if (settingsState.hasError)
                    _SettingsNotice.error(
                      onRetry: () => ref.invalidate(appSettingsProvider),
                    ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Kontak Admin',
                    icon: Icons.support_agent_rounded,
                    children: [
                      const _InfoRow(
                        label: 'Telepon/WhatsApp',
                        value: _adminPhone,
                        copyValue: _adminPhoneRaw,
                      ),
                      _InfoRow(
                        label: 'Email',
                        value: settings?.contactEmail ?? '',
                      ),
                      _InfoRow(
                        label: 'Lokasi Unit',
                        value: settings?.contactLocation ?? '',
                      ),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
                  _SectionCard(
                    title: 'Jam Layanan',
                    icon: Icons.schedule_rounded,
                    children: [
                      _InfoRow(
                        label: 'Hari & Jam',
                        value: settings?.contactHours ?? '',
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _responseNote,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: SibasColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
                  const _SectionCard(
                    title: 'Alur Pengaduan',
                    icon: Icons.assignment_rounded,
                    children: [
                      _StepRow(
                        number: '1',
                        text: 'Sampaikan pengaduan lewat kontak admin di atas.',
                      ),
                      _StepRow(
                        number: '2',
                        text: 'Admin mencatat dan meninjau laporan Anda.',
                      ),
                      _StepRow(
                        number: '3',
                        text: 'Tanggapan dikirim balik ke kontak yang Anda '
                            'pakai.',
                      ),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
                  const _ComplaintFormCard(),
                ],
              ),
            ),
          ),
          // Ruang bawah 96 px + safe area (§4).
          SliverToBoxAdapter(
            child: SizedBox(height: 96 + bottomInset),
          ),
        ],
      ),
    );
  }
}

/// Nilai "Belum diatur" ditampilkan apa adanya, tanpa data karangan.
String _display(String value) {
  final text = value.trim();
  return text.isEmpty ? 'Belum diatur' : text;
}

/// Keterangan kecil di atas kartu kontak saat pengaturan belum siap.
class _SettingsNotice extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onRetry;

  const _SettingsNotice.loading()
      : isLoading = true,
        onRetry = null;

  const _SettingsNotice.error({required this.onRetry}) : isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isError = !isLoading;
    final accent = isError ? SibasColors.status.badText : SibasColors.leaf;

    return SurfaceCard(
      color: isError
          ? SibasColors.status.rejectedBackground
          : SibasColors.mintWash,
      radius: 16,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent,
              ),
            )
          else
            Icon(Icons.cloud_off_rounded, size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isLoading
                  ? 'Memuat kontak admin…'
                  : 'Kontak admin belum bisa dimuat. Nilai di bawah tampil '
                      'sebagai "Belum diatur".',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: isError ? SibasColors.status.badText : SibasColors.muted,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: SibasColors.status.badText,
                minimumSize: const Size(0, _touchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Coba Lagi'),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: _cardRadius,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SibasColors.mintWash,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: SibasColors.leaf),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: _sectionTitle)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  /// Bila diisi, baris menampilkan tombol salin di kanan nilai.
  final String? copyValue;

  const _InfoRow({required this.label, required this.value, this.copyValue});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: copyValue!));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nomor admin disalin'),
        backgroundColor: SibasColors.leaf,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _display(value);
    final isUnset = shown == 'Belum diatur';
    final valueStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: isUnset ? FontWeight.w500 : FontWeight.w600,
      fontStyle: isUnset ? FontStyle.italic : FontStyle.normal,
      height: 1.4,
      color: isUnset ? SibasColors.muted : SibasColors.text,
      fontFeatures: _tabular,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label dan nilai dibaca sebagai satu kalimat oleh pembaca layar;
          // teks visual tidak memunculkan duplikat.
          Expanded(
            child: Semantics(
              container: true,
              label: '$label: $shown',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _rowLabel),
                  const SizedBox(height: 4),
                  Text(shown, style: valueStyle),
                ],
              ),
            ),
          ),
          if (copyValue != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _copy(context),
              tooltip: 'Salin nomor admin',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: _touchTarget,
                minHeight: _touchTarget,
              ),
              icon: Icon(
                Icons.copy_rounded,
                size: 18,
                color: SibasColors.leaf,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;

  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SibasColors.mintWash,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: SibasColors.primary,
                fontFeatures: _tabular,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: SibasColors.text,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintFormCard extends StatelessWidget {
  const _ComplaintFormCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: SibasColors.mintWash,
      radius: _cardRadius,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Formulir Pengaduan', style: _sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Pengaduan ditanggapi maksimal 1×24 jam pada hari kerja.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: SibasColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Belum tersedia: tombol sengaja mati agar tidak menyesatkan.
              onPressed: null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Buka Formulir Pengaduan'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Formulir pengaduan belum tersedia. Sampaikan pengaduan melalui '
            'kontak admin di atas.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: SibasColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seksi konten: lebar maksimal 720 px dengan gutter 16/32 (§4, §10.5).
class _ContentSection extends StatelessWidget {
  final Widget child;

  const _ContentSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      maxWidth: _maxContentWidth,
      child: Padding(
        padding: const EdgeInsets.only(top: _sectionGap),
        child: child,
      ),
    );
  }
}

/// Batas lebar yang sama untuk hero, agar tepi kartu sejajar dengan seksi.
class _WidthLimit extends StatelessWidget {
  final Widget child;

  const _WidthLimit({required this.child});

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
