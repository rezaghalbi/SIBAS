import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../bank_location/domain/models/bank_location_model.dart';
import '../../../bank_location/presentation/providers/bank_location_provider.dart';
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

/// Radius kartu konten (r-20) dan panel di dalamnya (r-16) sesuai §4.
const double _cardRadius = 20;
const double _innerRadius = 16;

/// Radius sheet (r-28) sesuai §4.
const double _sheetRadius = 28;

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

    final lokasi = ref.read(selectedLocationProvider);
    if (lokasi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih lokasi bank sampah terlebih dahulu'),
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
        locationId: lokasi.id,
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
    final hasLocation = ref.watch(selectedLocationProvider) != null;
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
                  canSubmit: hasLocation,
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
        const Text('Lokasi Bank Sampah', style: _sectionTitle),
        const SizedBox(height: 12),
        const _LocationSection(),
        const SizedBox(height: 24),
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
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
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
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
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
    final lokasi = ref.watch(selectedLocationProvider);
    final rate = category?.pricePerKg ?? 0;
    final unit = category?.unit ?? 'kg';
    final hasRate = rate > 0;
    final typedWeight = _weightController.text.trim();

    return _SummaryCard(
      locationName: lokasi?.name,
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
      canSubmit: lokasi != null,
      onSubmit: _handleSubmit,
    );
  }
}

/// Pengingat singkat cara kerja setoran dan masa berlaku QR.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      radius: _innerRadius,
      color: AppColors.mintSoftBackground,
      padding: EdgeInsets.all(16),
      child: Row(
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
      child: SurfaceCard(
        radius: _innerRadius,
        tone: SurfaceTone.subtle,
        // Tile terpilih ditandai tint, centang, dan warna teks. Border tetap
        // 1 px netral dari `SurfaceCard` agar seragam dengan panel lain.
        color: isSelected
            ? AppColors.primaryMain.withValues(alpha: 0.14)
            : null,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_innerRadius),
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
  final String? locationName;
  final String? categoryName;
  final String weightLabel;
  final String priceLabel;
  final String totalLabel;
  final bool showCta;
  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  const _SummaryCard({
    required this.locationName,
    required this.categoryName,
    required this.weightLabel,
    required this.priceLabel,
    required this.totalLabel,
    required this.showCta,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: _cardRadius,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Setoran', style: _sectionTitle),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Lokasi',
            value: locationName ?? 'Belum dipilih',
          ),
          const SizedBox(height: 10),
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
              canSubmit: canSubmit,
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
/// Nonaktif selama lokasi bank sampah belum dipilih.
class _SubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onSubmit;

  const _SubmitButton({
    required this.isSubmitting,
    required this.canSubmit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: (isSubmitting || !canSubmit) ? null : onSubmit,
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
  final bool canSubmit;
  final VoidCallback onSubmit;

  const _StickyCta({
    required this.isSubmitting,
    required this.canSubmit,
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
            canSubmit: canSubmit,
            onSubmit: onSubmit,
          ),
        ),
      ),
    );
  }
}

/// Blok pemilih lokasi bank sampah.
///
/// Status muat dan galat dibaca dari [bankLocationsProvider]; daftar lokasi
/// aktif diturunkan lewat [activeLocationsProvider] yang bernilai kosong saat
/// memuat, jadi tidak boleh dipakai sendirian untuk mendeteksi loading.
class _LocationSection extends ConsumerStatefulWidget {
  const _LocationSection();

  @override
  ConsumerState<_LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends ConsumerState<_LocationSection> {
  @override
  void initState() {
    super.initState();
    // Tulis provider setelah frame pertama: Riverpod melarang perubahan
    // state provider saat widget tree masih dibangun.
    WidgetsBinding.instance.addPostFrameCallback((_) => _selaraskanPilihan());
  }

  /// Isi otomatis bila hanya ada satu lokasi aktif, dan buang pilihan yang
  /// sudah tidak ada di daftar. Idempoten: selama pilihan masih valid tidak
  /// ada penulisan provider, sehingga tidak mungkin berputar (loop).
  void _selaraskanPilihan() {
    if (!mounted) return;

    final aktif = ref.read(activeLocationsProvider);
    final terpilih = ref.read(selectedLocationProvider);
    final masihValid = terpilih != null &&
        aktif.any((lokasi) => lokasi.id == terpilih.id);
    if (masihValid) return;

    final berikutnya = aktif.length == 1 ? aktif.first : null;
    if (berikutnya?.id == terpilih?.id) return;
    ref.read(selectedLocationProvider.notifier).state = berikutnya;
  }

  Future<void> _pilihLokasi(List<BankLocationModel> aktif) async {
    final terpilih = await showModalBottomSheet<BankLocationModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (_) => _LocationSheet(
        lokasi: aktif,
        terpilihId: ref.read(selectedLocationProvider)?.id,
      ),
    );
    if (terpilih == null || !mounted) return;
    ref.read(selectedLocationProvider.notifier).state = terpilih;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bankLocationsProvider);
    // Data baru (termasuk hasil "Coba Lagi") ikut diselaraskan.
    ref.listen<AsyncValue<List<BankLocationModel>>>(
      bankLocationsProvider,
      (_, next) {
        if (next.hasValue) Future.microtask(_selaraskanPilihan);
      },
    );

    final aktif = ref.watch(activeLocationsProvider);
    final terpilih = ref.watch(selectedLocationProvider);

    return SurfaceCard(
      radius: _innerRadius,
      tone: SurfaceTone.card,
      padding: EdgeInsets.zero,
      child: _buildIsi(state, aktif, terpilih),
    );
  }

  Widget _buildIsi(
    AsyncValue<List<BankLocationModel>> state,
    List<BankLocationModel> aktif,
    BankLocationModel? terpilih,
  ) {
    if (state.isLoading && !state.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Memuat lokasi bank sampah…',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    if (state.hasError && !state.hasValue) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _LocationError(
          onRetry: () => ref.invalidate(bankLocationsProvider),
        ),
      );
    }

    if (aktif.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _LocationEmpty(),
      );
    }

    // Satu lokasi aktif: tampil sebagai baris terpilih tanpa pemilih.
    if (aktif.length == 1) {
      return _LocationRow(lokasi: aktif.first, tetap: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocationRow(
          lokasi: terpilih,
          tetap: false,
          onTap: () => _pilihLokasi(aktif),
        ),
        if (terpilih == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: AppColors.danger,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lokasi belum dipilih. Pilih lokasi untuk melanjutkan.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Satu baris lokasi: nama + alamat. Tinggi isi 40 px ditambah padding
/// membuat target sentuh tetap di atas 44 px.
class _LocationRow extends StatelessWidget {
  final BankLocationModel? lokasi;
  final bool tetap;
  final VoidCallback? onTap;

  const _LocationRow({
    required this.lokasi,
    required this.tetap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final kosong = lokasi == null;
    final alamat = lokasi?.address.trim() ?? '';
    final keterangan = alamat.isNotEmpty
        ? alamat
        : (tetap
            ? 'Satu-satunya lokasi aktif.'
            : 'Ketuk untuk melihat daftar lokasi.');

    final isi = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.mintSoftBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.place_rounded,
              size: 20,
              color: kosong ? AppColors.textMuted : AppColors.primaryMain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lokasi?.name ?? 'Pilih lokasi bank sampah',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kosong
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  keterangan,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (tetap)
            const _TerpilihBadge()
          else
            const Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
        ],
      ),
    );

    if (onTap == null) return isi;

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_innerRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: isi),
      ),
    );
  }
}

/// Penanda lokasi tunggal yang sudah terpilih otomatis.
class _TerpilihBadge extends StatelessWidget {
  const _TerpilihBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryMain.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titik penanda status (§2): jangan andalkan warna saja.
          SizedBox(
            width: 5,
            height: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primaryMain,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Terpilih',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tidak ada lokasi aktif: setoran belum bisa diajukan.
class _LocationEmpty extends StatelessWidget {
  const _LocationEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Belum ada lokasi bank sampah aktif.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Setoran dan penarikan belum bisa diajukan sampai admin '
                    'mengaktifkan lokasi.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: null,
            child: Text('Pilih Lokasi'),
          ),
        ),
      ],
    );
  }
}

/// Gagal memuat daftar lokasi; pengguna bisa mencoba lagi.
class _LocationError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LocationError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.danger,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lokasi bank sampah gagal dimuat.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Periksa koneksi lalu coba lagi.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryMain,
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ),
      ],
    );
  }
}

/// Sheet pilihan lokasi. Kaca hanya dipakai di lapisan mengambang ini.
class _LocationSheet extends StatelessWidget {
  final List<BankLocationModel> lokasi;
  final String? terpilihId;

  const _LocationSheet({required this.lokasi, this.terpilihId});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: GlassPanel(
          tone: GlassTone.dense,
          radius: _sheetRadius,
          padding: EdgeInsets.zero,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Pilih Lokasi Bank Sampah',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: lokasi.length,
                    itemBuilder: (context, index) {
                      final item = lokasi[index];
                      return _LocationOption(
                        lokasi: item,
                        dipilih: item.id == terpilihId,
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
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

/// Satu pilihan lokasi di dalam sheet; tinggi baris 60 px.
class _LocationOption extends StatelessWidget {
  final BankLocationModel lokasi;
  final bool dipilih;
  final VoidCallback onTap;

  const _LocationOption({
    required this.lokasi,
    required this.dipilih,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final alamat = lokasi.address.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: dipilih
            ? AppColors.primaryMain.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(_innerRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.mintSoftBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    size: 18,
                    color: AppColors.primaryMain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lokasi.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (alamat.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          alamat,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dipilih) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.primaryMain,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
