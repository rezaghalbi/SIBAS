import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_palette.dart';
import '../../../../core/constants/theme.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/validasi_profil.dart';

/// Edit data akun: foto, nama, NIM, dan nomor WhatsApp. Email hanya baca dan
/// diubah lewat menu Ubah Email di layar Profil.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _nim = TextEditingController();
  final _wa = TextEditingController();

  bool _terisi = false;
  bool _fotoSibuk = false;
  bool _simpanSibuk = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _isiForm(ref.read(currentUserProvider).valueOrNull);
  }

  @override
  void dispose() {
    _nama.dispose();
    _nim.dispose();
    _wa.dispose();
    super.dispose();
  }

  /// Nilai awal hanya diisi sekali supaya ketikan pengguna tidak tertimpa.
  void _isiForm(UserModel? user) {
    if (user == null || _terisi) return;
    _terisi = true;
    _nama.text = user.fullName;
    _nim.text = user.nim ?? '';
    _wa.text = user.phone ?? '';
  }

  Future<void> _simpan() async {
    if (_simpanSibuk || _fotoSibuk) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _simpanSibuk = true;
      _galat = null;
    });
    try {
      await ref.read(currentUserProvider.notifier).ubahProfil(
            nama: _nama.text.trim(),
            nim: _nim.text.trim(),
            phone: _wa.text.trim(),
          );
      if (!mounted) return;
      _snack(context, 'Profil diperbarui');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _simpanSibuk = false;
        _galat = pesanKesalahan(e);
      });
    }
  }

  Future<void> _pilihSumberFoto(bool adaFoto) async {
    final p = AppPalette.of(context);
    final warna = AppStatusColors.of(p.brightness);
    final aksi = await showModalBottomSheet<_AksiFoto>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.bottomSheetRadius),
        ),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Foto Profil',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const _IkonSheet(icon: Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(ctx, _AksiFoto.kamera),
            ),
            ListTile(
              leading: const _IkonSheet(icon: Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, _AksiFoto.galeri),
            ),
            if (adaFoto)
              ListTile(
                leading: const _IkonSheet(
                  icon: Icons.delete_outline_rounded,
                  warna: warna.badText,
                ),
                title: const Text(
                  'Hapus Foto',
                  style: TextStyle(
                    color: warna.badText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, _AksiFoto.hapus),
              ),
            Divider(height: 1, color: p.border),
            ListTile(
              onTap: () => Navigator.pop(ctx),
              title: Center(
                child: Text(
                  'Batal',
                  style: TextStyle(
                    color: p.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (aksi == null || !mounted) return;
    if (aksi == _AksiFoto.hapus) {
      await _hapusFoto();
      return;
    }
    await _ambilFoto(
      aksi == _AksiFoto.kamera ? ImageSource.camera : ImageSource.gallery,
    );
  }

  Future<void> _ambilFoto(ImageSource sumber) async {
    if (_fotoSibuk) return;
    XFile? berkas;
    try {
      berkas = await ImagePicker().pickImage(
        source: sumber,
        maxWidth: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) _snack(context, 'Foto tidak dapat diambil. Coba lagi.');
      return;
    }
    if (berkas == null || !mounted) return;

    setState(() => _fotoSibuk = true);
    try {
      final bytes = await berkas.readAsBytes();
      await ref.read(currentUserProvider.notifier).ubahFotoProfil(
            bytes: bytes,
            mime: _mimeDariNama(berkas.name),
          );
      if (!mounted) return;
      _snack(context, 'Foto profil diperbarui');
    } catch (e) {
      if (!mounted) return;
      _snack(context, pesanKesalahan(e));
    } finally {
      if (mounted) setState(() => _fotoSibuk = false);
    }
  }

  Future<void> _hapusFoto() async {
    if (_fotoSibuk) return;
    setState(() => _fotoSibuk = true);
    try {
      await ref.read(currentUserProvider.notifier).hapusFotoProfil();
      if (!mounted) return;
      _snack(context, 'Foto profil dihapus');
    } catch (e) {
      if (!mounted) return;
      _snack(context, pesanKesalahan(e));
    } finally {
      if (mounted) setState(() => _fotoSibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    ref.listen(currentUserProvider, (_, next) => _isiForm(next.valueOrNull));

    final user = ref.watch(currentUserProvider).valueOrNull;
    final fotoUrl = ref.watch(avatarUrlProvider).valueOrNull;
    final email = user?.email ?? '';
    final bisaAksi = !_fotoSibuk && !_simpanSibuk;

    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          HeroHeader(
            title: 'Edit Profil',
            subtitle: 'Perbarui data akun Anda',
            trailing: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/profile');
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Semantics(
                              button: true,
                              label: 'Ubah foto profil',
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: bisaAksi
                                      ? () => _pilihSumberFoto(fotoUrl != null)
                                      : null,
                                  child: Container(
                                    width: 96,
                                    height: 96,
                                    clipBehavior: Clip.antiAlias,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: p.lime,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: p.border,
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (fotoUrl == null)
                                          _Inisial(nama: user?.fullName)
                                        else
                                          Image.network(
                                            fotoUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _Inisial(nama: user?.fullName),
                                          ),
                                        if (_fotoSibuk)
                                          Container(
                                            color: Colors.black.withValues(
                                              alpha: 0.35,
                                            ),
                                            alignment: Alignment.center,
                                            child: const SizedBox(
                                              width: 26,
                                              height: 26,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Ketuk foto untuk mengganti',
                              style: TextStyle(
                                fontSize: 12,
                                color: p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: p.border),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('Nama Lengkap'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nama,
                                enabled: bisaAksi,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'Nama lengkap',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                    color: p.leaf,
                                    size: 20,
                                  ),
                                ),
                                validator: validasiNama,
                              ),
                              const SizedBox(height: 14),
                              _label('NIM'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nim,
                                enabled: bisaAksi,
                                decoration: InputDecoration(
                                  hintText: 'Contoh: P07124220001',
                                  prefixIcon: Icon(
                                    Icons.badge_outlined,
                                    color: p.leaf,
                                    size: 20,
                                  ),
                                ),
                                validator: validasiNim,
                              ),
                              const SizedBox(height: 14),
                              _label('Nomor WhatsApp'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _wa,
                                enabled: bisaAksi,
                                keyboardType: TextInputType.phone,
                                autocorrect: false,
                                decoration: InputDecoration(
                                  hintText: 'Contoh: 081234567890',
                                  helperText:
                                      'Dipakai admin untuk menghubungi Anda',
                                  helperMaxLines: 2,
                                  prefixIcon: Icon(
                                    Icons.chat_outlined,
                                    color: p.leaf,
                                    size: 20,
                                  ),
                                ),
                                validator: validasiNomorWa,
                              ),
                              const SizedBox(height: 18),
                              _label('Email'),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: p.mintWash,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: p.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 18,
                                      color: p.muted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        email.isEmpty ? 'Belum diisi' : email,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: p.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Ubah lewat menu Ubah Email di Profil.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.muted,
                                ),
                              ),
                              if (_galat != null) ...[
                                const SizedBox(height: 14),
                                _BannerGalat(message: _galat!),
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: bisaAksi ? _simpan : null,
                                child: _simpanSibuk
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Simpan Perubahan'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AksiFoto { kamera, galeri, hapus }

/// Inisial di atas lingkaran `primaryLight`; teks gelap agar tetap terbaca.
class _Inisial extends StatelessWidget {
  final String? nama;

  const _Inisial({required this.nama});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    final parts = (nama ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final huruf = parts.isEmpty
        ? 'S'
        : parts.take(2).map((p) => p.substring(0, 1)).join().toUpperCase();

    return Center(
      child: Text(
        huruf,
        style: TextStyle(
          color: p.primary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IkonSheet extends StatelessWidget {
  final IconData icon;
  final Color warna;

  _IkonSheet({required this.icon, this.warna = p.leaf});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: p.mintWash,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: warna),
    );
  }
}

/// Galat simpan ditahan di form sampai percobaan berikutnya.
class _BannerGalat extends StatelessWidget {
  final String message;

  const _BannerGalat({required this.message});

  @override
  Widget build(BuildContext context) {
    final warna = AppStatusColors.of(p.brightness);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.rejectedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna.badText.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: warna.badText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: warna.badText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mime hanya dibutuhkan server; ekstensi sudah cukup tanpa membaca header.
String _mimeDariNama(String nama) {
  final n = nama.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

Widget _label(String teks) => Text(
      teks,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: p.text,
      ),
    );

void _snack(BuildContext context, String message) {
    final p = AppPalette.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.primary,
      ),
    );
}
