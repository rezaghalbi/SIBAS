import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/hero_header.dart';
import '../providers/app_settings_provider.dart';

/// Kontak resmi unit bank sampah. Isi hanya setelah admin menetapkan nilainya;
/// jangan mengarang nomor telepon/email. String kosong otomatis tampil
/// sebagai "Belum diatur".
const String _adminPhone = '+62 813-8902-1668';

/// Nomor mentah untuk aksi salin (tanpa spasi dan tanda hubung).
const String _adminPhoneRaw = '081389021668';

const String _responseNote =
    'Pengaduan ditanggapi maksimal 1×24 jam pada hari kerja';

/// Pusat informasi statis: kontak admin, jam layanan, dan alur pengaduan.
class InfoScreen extends ConsumerWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Saat memuat atau gagal, nilai tampil "Belum diatur" — bukan data karangan.
    final settings = ref.watch(appSettingsProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeroHeader(
              title: 'Pusat Informasi',
              subtitle: 'Kontak admin & pengaduan',
              mark: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/sibas-logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              trailing: IconButton(
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
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Jam Layanan',
                  icon: Icons.schedule_rounded,
                  children: [
                    _InfoRow(
                      label: 'Hari & Jam',
                      value: settings?.contactHours ?? '',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      _responseNote,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                      text: 'Tanggapan dikirim balik ke kontak yang Anda pakai.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _ComplaintFormCard(),
                const SizedBox(height: 24),
              ]),
            ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.mintSoftBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.primaryMain),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
      const SnackBar(
        content: Text('Nomor admin disalin'),
        backgroundColor: AppColors.primaryMain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _display(value);
    final isUnset = shown == 'Belum diatur';
    const labelStyle = TextStyle(fontSize: 13, color: AppColors.textMuted);
    final valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: isUnset ? FontWeight.w500 : FontWeight.w700,
      fontStyle: isUnset ? FontStyle.italic : FontStyle.normal,
      color: isUnset ? AppColors.textMuted : AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label dan nilai dibaca sebagai satu kalimat oleh pembaca layar;
          // teks visual tidak memunculkan duplikat.
          Expanded(
            child: Semantics(
              container: true,
              label: '$label: $shown',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(label, style: labelStyle),
                  ),
                  Expanded(child: Text(shown, style: valueStyle)),
                ],
              ),
            ),
          ),
          if (copyValue != null)
            IconButton(
              onPressed: () => _copy(context),
              icon: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppColors.primaryMain,
              ),
              tooltip: 'Salin nomor admin',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.mintSoftBackground,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.mintSoftBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mintAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Formulir Pengaduan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pengaduan ditanggapi maksimal 1×24 jam pada hari kerja.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Belum tersedia: tombol sengaja mati agar tidak menyesatkan.
              onPressed: null,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Buka Formulir Pengaduan'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Formulir pengaduan belum tersedia. Sampaikan pengaduan melalui kontak admin di atas.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
