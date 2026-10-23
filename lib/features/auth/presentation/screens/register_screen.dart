import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../profile/domain/validasi_profil.dart';
import '../../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/sibas_colors.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _nimController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _nimController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Pesan lama dibersihkan supaya tidak menyesatkan percobaan berikutnya.
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = await ref.read(currentUserProvider.notifier).register(
            email: _emailController.text,
            password: _passwordController.text,
            fullName: _fullNameController.text,
            nim: _nimController.text,
            phone: _phoneController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user == null
                  ? 'Pendaftaran berhasil. Cek email untuk verifikasi sebelum masuk.'
                  : 'Pendaftaran berhasil!',
            ),
            backgroundColor: SibasColors.leaf,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Kegagalan ditampilkan permanen di form, bukan SnackBar 4 detik.
        setState(() => _errorMessage = authErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: SibasColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GlassPanel(
                radius: 24,
                padding: const EdgeInsets.all(26.0),
                child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo SIBAS dengan graceful fallback
                        Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: SibasColors.mintWash,
                              shape: BoxShape.circle,
                              border: Border.all(color: SibasColors.mint, width: 2),
                            ),
                            padding: const EdgeInsets.all(10),
                            // Tanpa berkas logo: ikon wordmark bawaan.
                            child: Icon(
                              Icons.person_add_rounded,
                              size: 36,
                              color: SibasColors.leaf,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Daftar Akun SIBAS',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: SibasColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sistem Informasi Bank Sampah Poltekkes Jogja',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: SibasColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Registrasi hanya untuk mahasiswa; akun admin dibuat
                        // manual lewat Dashboard Supabase.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: SibasColors.mintWash,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.school_outlined, size: 18, color: SibasColors.leaf),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pendaftaran untuk akun mahasiswa. Akun admin dibuat oleh pengelola bank sampah.',
                                  style: TextStyle(fontSize: 12.5, color: SibasColors.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Nama Lengkap
                        Text(
                          'Nama Lengkap',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SibasColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            hintText: 'Masukkan nama lengkap',
                            prefixIcon: Icon(Icons.person_outline_rounded, color: SibasColors.leaf, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Nama lengkap wajib diisi';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // NIM
                        Text(
                          'NIM (Nomor Induk Mahasiswa)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SibasColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nimController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Contoh: P07124220001',
                            prefixIcon: Icon(Icons.badge_outlined, color: SibasColors.leaf, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'NIM wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Nomor WhatsApp — dipakai admin untuk menghubungi.
                        Text(
                          'Nomor WhatsApp',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SibasColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autocorrect: false,
                          decoration: InputDecoration(
                            hintText: 'Contoh: 081234567890',
                            helperText: 'Dipakai admin untuk menghubungi Anda',
                            helperMaxLines: 2,
                            prefixIcon: Icon(Icons.chat_outlined, color: SibasColors.leaf, size: 20),
                          ),
                          validator: validasiNomorWa,
                        ),
                        const SizedBox(height: 14),

                        // Email
                        Text(
                          'Email Kampus / Akun',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SibasColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'nama@poltekkes-jogja.ac.id',
                            prefixIcon: Icon(Icons.mail_outline_rounded, color: SibasColors.leaf, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Email wajib diisi';
                            if (!val.contains('@')) return 'Format email tidak valid';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password
                        Text(
                          'Kata Sandi',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SibasColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Minimal 6 karakter',
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: SibasColors.leaf, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: SibasColors.muted,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Kata sandi wajib diisi';
                            if (val.length < 6) return 'Kata sandi minimal 6 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Konfirmasi Kata Sandi — hanya divalidasi di klien,
                        // nilainya tidak dikirim ke server.
                        Text(
                          'Ulangi Kata Sandi',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SibasColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Ulangi kata sandi',
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: SibasColors.leaf, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Ulangi kata sandi';
                            if (val != _passwordController.text) return 'Kata sandi tidak sama';
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),

                        // Kegagalan registrasi ditampilkan menetap sampai percobaan berikutnya.
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SibasColors.status.rejectedBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: SibasColors.status.badText.withValues(alpha: 0.35),
                              ),
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
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: SibasColors.status.badText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Tombol Submit
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text('Daftar Sekarang'),
                        ),
                        const SizedBox(height: 16),

                        // Link Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sudah punya akun? ', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Text(
                                'Masuk di sini',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: SibasColors.leaf,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
