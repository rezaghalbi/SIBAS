import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/sibas_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isResending = false;
  String? _verificationNotice;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Pesan lama dibersihkan supaya tidak menyesatkan percobaan berikutnya.
    setState(() {
      _errorMessage = null;
      _verificationNotice = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(currentUserProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
    } catch (e) {
      if (mounted) {
        final needsVerification = isEmailNotConfirmed(e);
        setState(() {
          _verificationNotice = needsVerification ? authErrorMessage(e) : null;
          // Kegagalan selain verifikasi email ditampilkan permanen di form,
          // bukan SnackBar 4 detik yang mudah terlewat.
          _errorMessage = needsVerification ? null : authErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final terkirim = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(
        emailAwal: _emailController.text.trim(),
      ),
    );
    if (!mounted || terkirim == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Tautan atur ulang sandi dikirim ke $terkirim. Periksa kotak masuk.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: SibasColors.primary,
        ),
      );
  }

  Future<void> _handleResend() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Isi email terlebih dahulu untuk mengirim ulang verifikasi'),
          backgroundColor: SibasColors.status.badText,
        ),
      );
      return;
    }

    setState(() => _isResending = true);
    try {
      await ref.read(currentUserProvider.notifier).resendVerification(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email verifikasi dikirim ulang ke $email'),
            backgroundColor: SibasColors.leaf,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authErrorMessage(e)),
            backgroundColor: SibasColors.status.badText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassPanel(
                radius: 24,
                padding: const EdgeInsets.all(26.0),
                child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo resmi SIBAS dari assets/images/sibas-logo.png
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.asset(
                                'assets/images/sibas-logo.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'SIBAS',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: SibasColors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bank Sampah Poltekkes Kemenkes Yogyakarta',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: SibasColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Role tidak dipilih di klien: server menentukan admin/mahasiswa
                        // lewat tabel profiles, lalu router mengarahkan ke dashboard sesuai role.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: SibasColors.mintWash,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: SibasColors.leaf),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Masuk sebagai mahasiswa atau admin — diarahkan otomatis sesuai akun.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 12,
                                    color: SibasColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Pemberitahuan email belum diverifikasi
                        if (_verificationNotice != null) ...[
                          Container(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                            decoration: BoxDecoration(
                              color: SibasColors.status.rejectedBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: SibasColors.status.badText.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.mark_email_unread_outlined,
                                      size: 18,
                                      color: SibasColors.status.badText,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _verificationNotice!,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: SibasColors.status.badText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _isResending ? null : _handleResend,
                                    child: Text(
                                      _isResending
                                          ? 'Mengirim...'
                                          : 'Kirim ulang email verifikasi',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email Field
                        Text(
                          'Email Kampus / Akun',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SibasColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 16),

                        // Password Field
                        Text(
                          'Kata Sandi',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SibasColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _handleForgotPassword,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Lupa kata sandi?',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: SibasColors.leaf,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Kegagalan login ditampilkan menetap sampai percobaan berikutnya.
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
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text('Masuk Sekarang'),
                        ),
                        const SizedBox(height: 16),

                        // Link Registrasi Akun
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Belum terdaftar? ',
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => context.go('/register'),
                              child: Text(
                                'Buat Akun Baru',
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

/// Dialog kirim tautan reset sandi. Galat ditahan di dialog supaya email bisa
/// diperbaiki tanpa membuka ulang.
class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  final String emailAwal;

  const _ForgotPasswordDialog({required this.emailAwal});

  @override
  ConsumerState<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.emailAwal,
  );
  bool _sibuk = false;
  String? _galat;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? _validasiEmail(String? val) {
    final value = val?.trim() ?? '';
    if (value.isEmpty) return 'Email wajib diisi';
    final at = value.indexOf('@');
    if (at <= 0 || !value.substring(at + 1).contains('.')) {
      return 'Format email tidak valid';
    }
    return null;
  }

  Future<void> _kirim() async {
    if (_sibuk) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      final notifier = ref.read(currentUserProvider.notifier);
      await notifier.kirimTautanResetSandi(email);
      if (!mounted) return;
      Navigator.pop(context, email);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galat = pesanKesalahan(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Lupa Kata Sandi',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan email akun. Kami kirim tautan untuk mengatur ulang '
              'kata sandi.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: SibasColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofocus: widget.emailAwal.isEmpty,
              decoration: InputDecoration(
                hintText: 'nama@poltekkes-jogja.ac.id',
                prefixIcon: Icon(
                  Icons.mail_outline_rounded,
                  color: SibasColors.leaf,
                  size: 20,
                ),
              ),
              validator: _validasiEmail,
            ),
            if (_galat != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SibasColors.status.rejectedBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: SibasColors.status.badText.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: SibasColors.status.badText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _galat!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: SibasColors.status.badText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sibuk ? null : () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: TextStyle(color: SibasColors.muted),
          ),
        ),
        ElevatedButton(
          onPressed: _sibuk ? null : _kirim,
          child: _sibuk
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kirim Tautan'),
        ),
      ],
    );
  }
}
