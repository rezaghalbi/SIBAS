import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _nimController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _nimController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _currentRole => _tabController.index == 0 ? 'mahasiswa' : 'admin';

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(currentUserProvider.notifier).register(
            email: _emailController.text,
            password: _passwordController.text,
            fullName: _fullNameController.text,
            role: _currentRole,
            nim: _currentRole == 'mahasiswa' ? _nimController.text : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pendaftaran berhasil!'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pendaftaran gagal: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.borderLine, width: 1),
                ),
                child: Padding(
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
                              color: AppColors.mintSoftBackground,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.mintAccent, width: 2),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              'assets/images/logo_sibas.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person_add_rounded,
                                  size: 36,
                                  color: AppColors.primaryMain,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Daftar Akun SIBAS',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sistem Informasi Bank Sampah Poltekkes Jogja',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tab Pemilihan Role
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.mintSoftBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            onTap: (_) => setState(() {}),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              color: AppColors.primaryMain,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: AppColors.textMuted,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            tabs: const [
                              Tab(text: 'Mahasiswa'),
                              Tab(text: 'Petugas Admin'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Nama Lengkap
                        Text(
                          'Nama Lengkap',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            hintText: 'Masukkan nama lengkap',
                            prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primaryMain, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Nama lengkap wajib diisi';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Input NIM jika tab Mahasiswa aktif
                        if (_currentRole == 'mahasiswa') ...[
                          Text(
                            'NIM (Nomor Induk Mahasiswa)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nimController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Contoh: P07124220001',
                              prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primaryMain, size: 20),
                            ),
                            validator: (val) {
                              if (_currentRole == 'mahasiswa' && (val == null || val.trim().isEmpty)) {
                                return 'NIM wajib diisi untuk mahasiswa';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Email
                        Text(
                          'Email Kampus / Akun',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'nama@poltekkes-jogja.ac.id',
                            prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.primaryMain, size: 20),
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
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Minimal 6 karakter',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryMain, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.textMuted,
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
                        const SizedBox(height: 22),

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
                                  color: AppColors.primaryMain,
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
      ),
    );
  }
}
