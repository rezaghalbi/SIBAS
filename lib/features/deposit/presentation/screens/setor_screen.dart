import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(depositRepositoryProvider);
      final tx = await repo.createDepositTransaction(
        userId: currentUser.id,
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        weightKg: _weight,
        estimatedAmount: _estimatedTotal,
      );

      if (mounted) {
        // Navigasi langsung ke QR Screen
        context.push('/qr/${tx.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat setoran: ${e.toString()}'),
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
          padding: const EdgeInsets.all(20.0),
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
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.25,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = _selectedCategory?.id == cat.id;

                        return InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.mintSoftBackground : AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryMain : AppColors.borderLine,
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
                                    Icon(
                                      _getCategoryIcon(cat.name),
                                      color: isSelected ? AppColors.primaryMain : AppColors.textMuted,
                                      size: 26,
                                    ),
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
                                          : 'Non-komersial (${cat.unit})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? AppColors.primaryMain : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())),
                  error: (err, _) => Text('Gagal memuat kategori: $err'),
                ),
                const SizedBox(height: 24),

                // 2. Input Berat Manual (kg)
                const Text(
                  '2. Berat Sampah (kg)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Masukkan berat (contoh: 2.5)',
                    prefixIcon: Icon(Icons.scale_rounded, color: AppColors.primaryMain),
                    suffixText: 'kg',
                    suffixStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
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
                const SizedBox(height: 24),

                // 3. Ringkasan Kalkulasi Estimasi Nilai
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ringkasan Estimasi',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const Divider(height: 20, color: AppColors.borderLine),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kategori', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          Text(
                            _selectedCategory?.name ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Berat Masukan', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          Text(
                            '${_weight.toStringAsFixed(1)} kg',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tarif per kg', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          Text(
                            _selectedCategory != null && _selectedCategory!.pricePerKg > 0
                                ? _currencyFormat.format(_selectedCategory!.pricePerKg)
                                : 'Rp 0 (Fokus kg)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.borderLine),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimasi Tabungan',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          Text(
                            _currencyFormat.format(_estimatedTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.primaryMain,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Tombol Ajukan & Buat QR
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
        ),
      ),
    );
  }
}
