import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../trash_type/presentation/providers/trash_type_provider.dart';
import '../providers/deposit_provider.dart';
import '../../domain/models/waste_category_model.dart';

class SetorScreen extends ConsumerStatefulWidget {
  const SetorScreen({super.key});

  @override
  ConsumerState<SetorScreen> createState() => _SetorScreenState();
}

class _SetorScreenState extends ConsumerState<SetorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  WasteCategoryModel? _selectedCategory;
  double _weight = 0.0;
  bool _isSubmitting = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  double get _estimatedTotal {
    if (_selectedCategory == null || _weight <= 0) return 0.0;
    return _weight * _selectedCategory!.pricePerKg;
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('plastik')) return Icons.local_drink_rounded;
    if (lower.contains('kertas') || lower.contains('karton')) return Icons.description_rounded;
    if (lower.contains('kaleng') || lower.contains('logam')) return Icons.hardware_rounded;
    if (lower.contains('kaca') || lower.contains('beling')) return Icons.wine_bar_rounded;
    if (lower.contains('jelantah') || lower.contains('minyak')) return Icons.opacity_rounded;
    return Icons.recycling_rounded;
  }

  Widget _categoryThumb(WasteCategoryModel cat, {required bool isSelected}) {
    final icon = Icon(
      _getCategoryIcon(cat.name),
      color: isSelected ? AppColors.primaryMain : AppColors.textMuted,
      size: 26,
    );
    final path = cat.imagePath;
    if (path == null || path.isEmpty) return icon;

    return Consumer(
      builder: (context, ref, _) {
        final url = ref.watch(fotoJenisSampahUrlProvider(path));
        if (url == null || url.isEmpty) return icon;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => icon,
          ),
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih jenis sampah terlebih dahulu'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(depositRepositoryProvider);
      final tx = await repo.createDepositTransaction(
        categoryId: _selectedCategory!.id,
        weightKg: _weight,
      );

      if (mounted) {
        // Navigasi langsung ke QR Screen
        context.push('/qr/${tx.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // RPC melempar pesan Indonesia (mis. tarif belum diatur); selain itu generik.
            content: Text(
              e is PostgrestException && e.message.isNotEmpty
                  ? e.message
                  : 'Gagal membuat setoran. Periksa koneksi lalu coba lagi.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(wasteCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Form Setor Sampah'),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.mintSoftBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.mintAccent),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.primaryMain, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Timbang dan masukkan berat sampah secara manual (kg). QR Code akan berlaku selama 2 jam untuk dipindai petugas.',
                          style: TextStyle(fontSize: 12, color: AppColors.primaryDark, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Pilihan Kategori Sampah
                const Text(
                  '1. Pilih Jenis Sampah',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                categoriesState.when(
                  data: (categories) {
                    return GlassPanel(
                      radius: 24,
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        // Lebar sel dibatasi 240 px dan tinggi dipatok 108 px:
                        // 2 kolom di 360, 3 di 768, 5 di 1280 tanpa kartu
                        // melebar. `ceil(extent / (240 + 10))` yang menentukan
                        // jumlah kolom, jadi nilai 232 akan menghasilkan 6
                        // kolom di 1280.
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: 108,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = _selectedCategory?.id == cat.id;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryMain.withValues(alpha: 0.16)
                                    : Colors.white.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryMain
                                      : Colors.white.withValues(alpha: 0.35),
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _categoryThumb(cat, isSelected: isSelected),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.primaryMain,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cat.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cat.pricePerKg > 0
                                            ? '${_currencyFormat.format(cat.pricePerKg)} / ${cat.unit}'
                                            : '${cat.unit} saja',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? AppColors.primaryMain : AppColors.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())),
                  error: (err, _) => Text('Gagal memuat kategori: $err'),
                ),
                const SizedBox(height: 24),

                // 2. Input Berat & Kirim
                GlassPanel(
                  radius: 24,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Berat Sampah (kg)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Masukkan berat (contoh: 2.5)',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.65),
                          prefixIcon: const Icon(Icons.scale_rounded, color: AppColors.primaryMain),
                          suffixText: 'kg',
                          suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _weight = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                          });
                        },
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Berat wajib diisi';
                          final parsed = double.tryParse(val.replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) return 'Berat harus bernilai numerik lebih dari 0 kg';
                          return null;
                        },
                      ),
                      if (_selectedCategory != null && _selectedCategory!.pricePerKg > 0) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Estimasi tabungan',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                            Text(
                              _currencyFormat.format(_estimatedTotal),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryMain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Nilai estimasi, bukan nominal final.',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          icon: _isSubmitting
                              ? const SizedBox.shrink()
                              : const Icon(Icons.qr_code_2_rounded, size: 22),
                          label: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text('Buat QR Transaksi Setoran'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
