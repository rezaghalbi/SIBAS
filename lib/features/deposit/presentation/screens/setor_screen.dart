import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../trash_type/presentation/providers/trash_type_provider.dart';
import '../../domain/models/waste_category_model.dart';
import '../providers/deposit_provider.dart';

/// Judul seksi Glass 2.0 (§3): 15.5 px, w700, tracking rapat.
const TextStyle _sectionTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  height: 1.25,
  color: AppColors.textPrimary,
);

/// Uang dan berat selalu tabular agar kolom tidak bergeser (§3).
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Kartu konten solid. Kaca hanya untuk lapisan mengambang (§7.1), jadi
/// panel kategori dan ringkasan tidak memakai `GlassPanel`.
BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.cardSurface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.borderLine),
  );
}

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
    if (lower.contains('kertas') || lower.contains('karton')) {
      return Icons.description_rounded;
    }
    if (lower.contains('kaleng') || lower.contains('logam')) {
      return Icons.hardware_rounded;
    }
    if (lower.contains('kaca') || lower.contains('beling')) {
      return Icons.wine_bar_rounded;
    }
    if (lower.contains('jelantah') || lower.contains('minyak')) {
      return Icons.opacity_rounded;
    }
    return Icons.recycling_rounded;
  }

  Widget _categoryThumb(
    WasteCategoryModel cat, {
    required bool isSelected,
  }) {
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
          borderRadius: BorderRadius.circular(12),
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
            // RPC melempar pesan Indonesia (mis. tarif belum diatur); selain
            // itu generik.
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
    final isWide = MediaQuery.sizeOf(context).width >= 1024;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    // CTA mengambang hanya di layar sempit. Saat keyboard terbuka ia
    // disembunyikan agar tidak menimpa field berat yang sedang diisi.
    final showStickyCta = !isWide && !keyboardOpen;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Form Setor Sampah'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                // 96 px ruang bawah (§4) supaya CTA mengambang tidak
                // menutupi isi terakhir.
                padding: const EdgeInsets.only(top: 16, bottom: 96),
                child: ContentWidth(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _InfoBanner(),
                        const SizedBox(height: 24),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildFormColumn(categoriesState),
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                // 320 px cukup untuk 3 baris ringkasan dan
                                // tombol; rail 268 px tetap menyisakan kolom
                                // kiri ±348 px di layar 1024.
                                width: 320,
                                child: _buildSummary(showCta: true),
                              ),
                            ],
                          )
                        else ...[
                          _buildFormColumn(categoriesState),
                          const SizedBox(height: 16),
                          _buildSummary(showCta: false),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showStickyCta)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StickyCta(
                  isSubmitting: _isSubmitting,
                  onSubmit: _handleSubmit,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormColumn(
    AsyncValue<List<WasteCategoryModel>> categoriesState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1. Pilih Jenis Sampah', style: _sectionTitle),
        const SizedBox(height: 12),
        _buildCategoryCard(categoriesState),
        const SizedBox(height: 24),
        const Text('2. Berat Sampah (kg)', style: _sectionTitle),
        const SizedBox(height: 12),
        _buildWeightCard(),
      ],
    );
  }

  Widget _buildCategoryCard(
    AsyncValue<List<WasteCategoryModel>> categoriesState,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: categoriesState.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Belum ada jenis sampah yang aktif.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // 2 kolom di 360, 3 kolom di ponsel lebar dan kolom kiri
              // desktop; tinggi sel tetap 108 agar kartu tidak melar.
              final columns = constraints.maxWidth >= 520 ? 3 : 2;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 108,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _selectedCategory?.id == cat.id;

                  return _CategoryTile(
                    name: cat.name,
                    priceLabel: cat.pricePerKg > 0
                        ? '${_currencyFormat.format(cat.pricePerKg)}'
                            ' / ${cat.unit}'
                        : '${cat.unit} saja',
                    isSelected: isSelected,
                    thumb: _categoryThumb(cat, isSelected: isSelected),
                    onTap: () => setState(() => _selectedCategory = cat),
                  );
                },
              );
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Gagal memuat kategori: $err',
            style: const TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ),
      ),
    );
  }

  Widget _buildWeightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: TextFormField(
        controller: _weightController,
        style: const TextStyle(fontSize: 16, fontFeatures: _tabular),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          hintText: 'Masukkan berat (contoh: 2.5)',
          fillColor: AppColors.background,
          prefixIcon: Icon(
            Icons.scale_rounded,
            color: AppColors.primaryMain,
          ),
          suffixText: 'kg',
          suffixStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        onChanged: (val) {
          setState(() {
            _weight = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
          });
        },
        validator: (val) {
          if (val == null || val.trim().isEmpty) return 'Berat wajib diisi';
          final parsed = double.tryParse(val.replaceAll(',', '.'));
          if (parsed == null || parsed <= 0) {
            return 'Berat harus bernilai numerik lebih dari 0 kg';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSummary({required bool showCta}) {
    final category = _selectedCategory;
    final rate = category?.pricePerKg ?? 0;
    final unit = category?.unit ?? 'kg';
    final hasRate = rate > 0;
    final typedWeight = _weightController.text.trim();

    return _SummaryCard(
      categoryName: category?.name,
      weightLabel: _weight > 0 && typedWeight.isNotEmpty
          ? '$typedWeight kg'
          : '—',
      priceLabel: hasRate
          ? '${_currencyFormat.format(rate)} / $unit'
          : '—',
      totalLabel: hasRate ? _currencyFormat.format(_estimatedTotal) : '—',
      showCta: showCta,
      isSubmitting: _isSubmitting,
      onSubmit: _handleSubmit,
    );
  }
}

/// Pengingat singkat cara kerja setoran dan masa berlaku QR.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mintSoftBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mintAccent),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryDark,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Timbang dan masukkan berat sampah secara manual (kg). '
              'QR Code berlaku 2 jam untuk dipindai petugas.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu pilihan jenis sampah. Seluruh sel adalah target sentuh 108 px.
class _CategoryTile extends StatelessWidget {
  final String name;
  final String priceLabel;
  final bool isSelected;
  final Widget thumb;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.name,
    required this.priceLabel,
    required this.isSelected,
    required this.thumb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryMain.withValues(alpha: 0.10)
              : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryMain : AppColors.borderLine,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      thumb,
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.primaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        priceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFeatures: _tabular,
                          color: isSelected
                              ? AppColors.primaryMain
                              : AppColors.textMuted,
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
    );
  }
}

/// Ringkasan setoran: kolom kanan di desktop, kartu terakhir di ponsel.
class _SummaryCard extends StatelessWidget {
  final String? categoryName;
  final String weightLabel;
  final String priceLabel;
  final String totalLabel;
  final bool showCta;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _SummaryCard({
    required this.categoryName,
    required this.weightLabel,
    required this.priceLabel,
    required this.totalLabel,
    required this.showCta,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Setoran', style: _sectionTitle),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Jenis sampah',
            value: categoryName ?? 'Belum dipilih',
          ),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Berat', value: weightLabel, tabular: true),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Harga / kg', value: priceLabel, tabular: true),
          const Divider(height: 28, color: AppColors.borderLine),
          const Text(
            'Estimasi tabungan',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            totalLabel,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              fontFeatures: _tabular,
              color: AppColors.primaryMain,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nilai estimasi, bukan nominal final.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (showCta) ...[
            const SizedBox(height: 20),
            _SubmitButton(
              isSubmitting: isSubmitting,
              onSubmit: onSubmit,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool tabular;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.tabular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: tabular ? _tabular : null,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Satu-satunya tombol aksi setor; dipakai di ringkasan dan CTA mengambang.
class _SubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _SubmitButton({
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isSubmitting ? null : onSubmit,
        icon: isSubmitting
            ? const SizedBox.shrink()
            : const Icon(Icons.qr_code_2_rounded, size: 20),
        label: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text('Buat QR Setoran'),
      ),
    );
  }
}

/// CTA menempel di bawah layar sempit; gradasi di atasnya memberi tanda
/// bahwa masih ada isi yang bisa digulir.
class _StickyCta extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _StickyCta({
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background,
          ],
          stops: const [0, 0.5],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
        child: ContentWidth(
          child: _SubmitButton(
            isSubmitting: isSubmitting,
            onSubmit: onSubmit,
          ),
        ),
      ),
    );
  }
}
