import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/sibas_colors.dart';

/// Layar atur sandi baru setelah pengguna membuka tautan reset dari email.
///
/// Hanya tampil selama `passwordRecoveryProvider` bernilai true; router yang
/// memaksa rute ini sehingga pengguna tidak bisa lanjut ke layar lain.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baru = TextEditingController();
  final _ulangi = TextEditingController();
  final List<bool> _obscure = List<bool>.filled(2, true);
  bool _sibuk = false;
  String? _galat;

  @override
  void dispose() {
    _baru.dispose();
    _ulangi.dispose();
    super.dispose();
  }

  void _toggle(int index) {
    setState(() => _obscure[index] = !_obscure[index]);
  }

  Future<void> _simpan() async {
    if (_sibuk) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    // Ditangkap sebelum jeda async: setelah logout, context bisa sudah dilepas.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    final notifier = ref.read(currentUserProvider.notifier);
    try {
      await notifier.simpanSandiBaru(_baru.text);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Kata sandi diperbarui. Silakan masuk kembali.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: SibasColors.primary,
          ),
        );
      await notifier.logout();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galat = pesanKesalahan(e);
      });
    }
  }

  Future<void> _batalkan() async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    ref.read(currentUserProvider.notifier).batalPemulihanSandi();
    await ref.read(currentUserProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _snack(context, 'Gunakan tombol Batalkan untuk keluar.');
      },
      child: Scaffold(
        backgroundColor: SibasColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: SibasColors.mintWash,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: SibasColors.border),
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          size: 26,
                          color: SibasColors.leaf,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Atur Kata Sandi Baru',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: SibasColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Buat kata sandi baru untuk akun Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: SibasColors.muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    GlassPanel(
                      radius: 24,
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _label('Kata Sandi Baru'),
                            const SizedBox(height: 6),
                            _sandiField(
                              controller: _baru,
                              hint: 'Minimal 8 karakter',
                              obscured: _obscure[0],
                              onToggle: () => _toggle(0),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Kata sandi baru wajib diisi';
                                }
                                if (val.length < 8) {
                                  return 'Kata sandi minimal 8 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _label('Ulangi Kata Sandi'),
                            const SizedBox(height: 6),
                            _sandiField(
                              controller: _ulangi,
                              hint: 'Ketik ulang kata sandi baru',
                              obscured: _obscure[1],
                              onToggle: () => _toggle(1),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Ulangi kata sandi wajib diisi';
                                }
                                if (val != _baru.text) {
                                  return 'Kata sandi tidak sama';
                                }
                                return null;
                              },
                            ),
                            if (_galat != null) ...[
                              const SizedBox(height: 14),
                              _KotakGalat(message: _galat!),
                            ],
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _sibuk ? null : _simpan,
                              child: _sibuk
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Simpan Kata Sandi'),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _sibuk ? null : _batalkan,
                              child: Text(
                                'Batalkan',
                                style: TextStyle(color: SibasColors.muted),
                              ),
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
      ),
    );
  }

  Widget _sandiField({
    required TextEditingController controller,
    required String hint,
    required bool obscured,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscured,
      enabled: !_sibuk,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: SibasColors.leaf,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: SibasColors.muted,
            size: 20,
          ),
          tooltip: obscured ? 'Lihat kata sandi' : 'Sembunyikan kata sandi',
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}

/// Galat simpan ditahan di layar sampai percobaan berikutnya.
class _KotakGalat extends StatelessWidget {
  final String message;

  const _KotakGalat({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SibasColors.status.rejectedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SibasColors.status.badText.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: SibasColors.status.badText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: SibasColors.status.badText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _label(String teks) => Text(
      teks,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: SibasColors.text,
      ),
    );

void _snack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SibasColors.primary,
      ),
    );
}
