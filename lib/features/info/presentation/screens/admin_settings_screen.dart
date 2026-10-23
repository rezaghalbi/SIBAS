import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/models/app_settings_model.dart';
import '../../domain/validasi_pengaturan.dart';
import '../providers/app_settings_provider.dart';

/// Target sentuh minimum (§4).
const double _touch = 44;

/// Lebar konten: sama dengan `ContentWidth` agar hero sejajar (§4).
const double _maxContentWidth = 1120;

/// Field 16 px agar Safari iOS tidak memperbesar halaman (§9).
const TextStyle _fieldText = TextStyle(
  fontSize: 16,
  color: AppColors.textPrimary,
);

/// Judul seksi: 15.5 w700, tracking -0.2 (§3).
const TextStyle _sectionTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: AppColors.textPrimary,
);

/// Pengaturan global aplikasi: masa berlaku QR dan kontak admin.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Dibuat sekali saat data pertama tiba; rebuild tidak menimpa isian admin.
  TextEditingController? _ttl;
  TextEditingController? _email;
  TextEditingController? _lokasi;
  TextEditingController? _jam;

  bool _menyimpan = false;

  /// Satu pesan saja: hasil simpan menggantikan pesan sebelumnya agar
  /// validasi, sukses, dan galat tidak menumpuk.
  String? _pesan;
  bool _pesanSukses = true;

  void _siapkan(AppSettingsModel data) {
    _ttl ??= TextEditingController(text: data.qrTtlMinutes.toString());
    _email ??= TextEditingController(text: data.contactEmail ?? '');
    _lokasi ??= TextEditingController(text: data.contactLocation ?? '');
    _jam ??= TextEditingController(text: data.contactHours ?? '');
  }

  @override
  void dispose() {
    _ttl?.dispose();
    _email?.dispose();
    _lokasi?.dispose();
    _jam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appSettingsProvider);
    final inset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(),
          ContentWidth(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 20, 0, 96 + inset),
              child: state.when(
                data: _form,
                loading: _kartuMemuat,
                error: (error, _) => _kartuGalat(error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hero memakai gutter sendiri; dibatasi lebar agar sejajar kartu isi.
  Widget _header() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: HeroHeader(
          title: 'Pengaturan Aplikasi',
          subtitle: 'Masa berlaku QR & kontak admin',
          trailing: IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.maybePop(context),
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
    );
  }

  Widget _form(AppSettingsModel data) {
    _siapkan(data);

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: _kartuTtl()),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: _kartuKontak()),
              ],
            )
          else ...[
            _kartuTtl(),
            const SizedBox(height: 16),
            _kartuKontak(),
          ],
          const SizedBox(height: 20),
          if (_pesan != null) ...[
            _pesanBanner(),
            const SizedBox(height: 16),
          ],
          _tombolSimpan(),
        ],
      ),
    );
  }

  /// CTA 48 px; di mobile mengisi lebar form, di desktop dibatasi 280 px.
  Widget _tombolSimpan() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _menyimpan ? null : _simpan,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.primaryMain.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: _menyimpan
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Simpan Pengaturan'),
          ),
        ),
      ),
    );
  }

  Widget _kartuTtl() {
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labelSeksi(Icons.timer_outlined, 'Masa Berlaku QR'),
          const SizedBox(height: 4),
          const Text(
            'Batas waktu satu QR setoran sebelum kedaluwarsa.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ttl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (teks) => validasiTtlQr(teks ?? ''),
            style: _fieldText,
            decoration: const InputDecoration(
              labelText: 'Masa berlaku QR (menit)',
              hintText: '120',
              suffixText: 'menit',
              helperText: 'Antara 5 sampai 1440 menit.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuKontak() {
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _labelSeksi(Icons.support_agent_rounded, 'Kontak Admin'),
          const SizedBox(height: 4),
          const Text(
            'Ditampilkan ke mahasiswa saat butuh bantuan.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (teks) => validasiEmailKontak(teks ?? ''),
            style: _fieldText,
            decoration: const InputDecoration(
              labelText: 'Email kontak',
              hintText: 'nama@contoh.id',
              helperText: 'Boleh dikosongkan.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lokasi,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (teks) => validasiTeksKontak(teks ?? ''),
            style: _fieldText,
            decoration: const InputDecoration(
              labelText: 'Lokasi unit',
              hintText: 'Alamat atau patokan unit bank sampah',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _jam,
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (teks) => validasiTeksKontak(teks ?? ''),
            style: _fieldText,
            decoration: const InputDecoration(
              labelText: 'Jam layanan',
              hintText: 'Senin–Jumat, 08.00–15.00',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const SurfaceCard(
            tone: SurfaceTone.subtle,
            radius: 12,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.primaryMain,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Perubahan berlaku untuk pengajuan setoran baru. '
                    'QR yang sudah terbit tidak berubah sampai '
                    'kedaluwarsa.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelSeksi(IconData icon, String teks) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.mintSoftBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 17, color: AppColors.primaryMain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            teks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _sectionTitle,
          ),
        ),
      ],
    );
  }

  Widget _pesanBanner() {
    final sukses = _pesanSukses;
    final ink = sukses
        ? AppColors.statusApprovedText
        : AppColors.statusRejectedText;
    final surface = sukses
        ? AppColors.statusApprovedBg
        : AppColors.statusRejectedBg;

    return SurfaceCard(
      tone: SurfaceTone.subtle,
      radius: 12,
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            sukses
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            size: 18,
            color: ink,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _pesan ?? '',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuMemuat() {
    return const SurfaceCard(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _kartuGalat(Object error) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.statusRejectedBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 26,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Gagal memuat pengaturan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pesanKesalahan(error),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _touch,
            child: OutlinedButton.icon(
              onPressed: () => ref.invalidate(appSettingsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, _touch),
                foregroundColor: AppColors.primaryMain,
                side: const BorderSide(color: AppColors.borderLine),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _simpan() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // Validasi tampil di tiap field; pesan lama dibuang agar tidak
      // menumpuk dengan galat baru.
      setState(() => _pesan = null);
      return;
    }

    setState(() {
      _menyimpan = true;
      _pesan = null;
    });

    final email = _email!.text.trim();
    final lokasi = _lokasi!.text.trim();
    final jam = _jam!.text.trim();

    try {
      await ref.read(appSettingsRepositoryProvider).updateSettings(
        qrTtlMinutes: int.parse(_ttl!.text.trim()),
        contactEmail: email.isEmpty ? null : email,
        contactLocation: lokasi.isEmpty ? null : lokasi,
        contactHours: jam.isEmpty ? null : jam,
      );
      if (!mounted) return;

      ref.invalidate(appSettingsProvider);
      setState(() {
        _pesan = 'Pengaturan aplikasi disimpan.';
        _pesanSukses = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pesan = pesanKesalahan(error);
        _pesanSukses = false;
      });
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }
}
