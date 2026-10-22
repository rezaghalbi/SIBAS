import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../domain/models/app_settings_model.dart';
import '../../domain/validasi_pengaturan.dart';
import '../providers/app_settings_provider.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: state.when(
              data: _form,
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _kartuGalat(error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return HeroHeader(
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
    );
  }

  Widget _form(AppSettingsModel data) {
    _siapkan(data);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            radius: 20,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _labelSeksi(Icons.timer_outlined, 'Masa Berlaku QR'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ttl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (teks) => validasiTtlQr(teks ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Masa berlaku QR (menit)',
                    hintText: '120',
                    suffixText: 'menit',
                    helperText: 'Antara 5 sampai 1440 menit.',
                  ),
                ),
                const SizedBox(height: 20),
                _labelSeksi(Icons.support_agent_rounded, 'Kontak Admin'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (teks) => validasiEmailKontak(teks ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Email kontak',
                    hintText: 'nama@contoh.id',
                    helperText: 'Boleh dikosongkan.',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lokasi,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (teks) => validasiTeksKontak(teks ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Lokasi unit',
                    hintText: 'Alamat atau patokan unit bank sampah',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _jam,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (teks) => validasiTeksKontak(teks ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Jam layanan',
                    hintText: 'Senin–Jumat, 08.00–15.00',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mintSoftBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.mintAccent),
                  ),
                  child: const Row(
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _menyimpan ? null : _simpan,
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor:
                          AppColors.primaryMain.withValues(alpha: 0.5),
                      disabledForegroundColor: Colors.white,
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
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.mintSoftBackground,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: AppColors.primaryMain),
        ),
        const SizedBox(width: 8),
        Text(
          teks,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _kartuGalat(Object error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.mintSoftBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 24,
              color: AppColors.primaryMain,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Gagal memuat pengaturan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
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
          ElevatedButton(
            onPressed: () => ref.invalidate(appSettingsProvider),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Future<void> _simpan() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _menyimpan = true);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan aplikasi disimpan.'),
          backgroundColor: AppColors.primaryMain,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pesanKesalahan(error)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }
}
