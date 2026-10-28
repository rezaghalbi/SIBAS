import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../bank_location/presentation/providers/bank_location_provider.dart';
import '../../../bank_location/presentation/widgets/location_section.dart';
import '../../../bank_location/domain/models/bank_location_model.dart';
import '../providers/withdrawal_provider.dart';
import '../widgets/withdraw_qr_sheet.dart';
import '../../../../core/theme/sibas_colors.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);


/// Judul seksi Glass 2.0 (§3): 15.5 px, w700, tracking rapat.
TextStyle get _sectionTitle => TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  height: 1.25,
  color: SibasColors.text,
);

/// Uang dan berat selalu tabular agar kolom tidak bergeser (§3).
const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// Lebar kolom konten. Form nominal tidak perlu selebar halaman (§8).
const double _contentMaxWidth = 640;

/// Radius kartu konten (r-20), panel status (r-16), dan catatan kecil
/// di dalam kartu (r-12) sesuai §4.
const double _cardRadius = 20;
const double _panelRadius = 16;
const double _noteRadius = 12;

/// Radius sheet (r-28) sesuai §4.

/// Pengajuan pencairan saldo tabungan sampah beserta riwayat penarikannya.
class TarikScreen extends ConsumerStatefulWidget {
  const TarikScreen({super.key});

  @override
  ConsumerState<TarikScreen> createState() => _TarikScreenState();
}

class _TarikScreenState extends ConsumerState<TarikScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  String? _validateAmount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Nominal penarikan wajib diisi.';

    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      return 'Nominal penarikan harus lebih dari 0.';
    }

    final balance = ref.read(availableBalanceProvider).valueOrNull ?? 0;
    if (amount > balance) {
      return 'Nominal melebihi saldo tersedia (${_currency.format(balance)}).';
    }
    return null;
  }

  /// Isi field dengan saldo bulat agar tidak melewati batas server.
  void _fillAll(double balance) {
    final whole = balance.floor();
    _amountController.text = whole > 0 ? '$whole' : '';
    _amountController.selection = TextSelection.collapsed(
      offset: _amountController.text.length,
    );
    setState(() => _error = null);
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    final balanceState = ref.read(availableBalanceProvider);
    if (!balanceState.hasValue || balanceState.hasError) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final lokasi = ref.read(selectedLocationProvider);
    if (lokasi == null) {
      setState(() => _error = 'Pilih lokasi bank sampah terlebih dahulu.');
      return;
    }

    final amount = _amount;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _error = null);

    final created = await ref
        .read(withdrawalControllerProvider.notifier)
        .create(amount, locationId: lokasi.id);
    if (!mounted) return;

    if (created == null) {
      final failure = ref.read(withdrawalControllerProvider).error;
      setState(() {
        _error = failure == null
            ? 'Pengajuan gagal dikirim. Periksa koneksi lalu coba lagi.'
            : pesanKesalahan(failure);
      });
      return;
    }

    _amountController.clear();
    setState(() => _error = null);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Pengajuan penarikan dikirim. Tunggu persetujuan admin.'),
      ),
    );

    // QR langsung ditampilkan agar mahasiswa bisa menunjukkan ke admin.
    final qrToken = created.qrToken;
    if (qrToken == null || qrToken.isEmpty || !mounted) return;
    await showWithdrawQrSheet(context, token: qrToken, amount: created.amount);
  }

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(availableBalanceProvider);
    final isSubmitting = ref.watch(withdrawalControllerProvider).isLoading;
    final lokasi = ref.watch(selectedLocationProvider);
    final hasLocation = lokasi != null;

    // Pesan "lokasi belum dipilih" hilang begitu pengguna memilih lokasi.
    ref.listen<BankLocationModel?>(selectedLocationProvider, (_, next) {
      if (next != null && _error != null) setState(() => _error = null);
    });

    final balance = balanceState.valueOrNull ?? 0;
    final balanceReady = balanceState.hasValue && !balanceState.hasError;

    return Scaffold(
      backgroundColor: SibasColors.background,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            // Hero ikut kolom 640 px agar tepinya sejajar dengan kartu form.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _contentMaxWidth,
                ),
                child: HeroHeader(
                  title: 'Tarik Dana',
                  subtitle: 'Pencairan saldo tabungan sampah',
                  trailing: const _BackButton(),
                  bottomContent: _BalancePanel(
                    state: balanceState,
                    balance: balance,
                    onRetry: () => ref.invalidate(availableBalanceProvider),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: _contentMaxWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildFormCard(
                  balance: balance,
                  balanceReady: balanceReady,
                  isSubmitting: isSubmitting,
                  hasLocation: hasLocation,
                  locationName: lokasi?.name,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: _contentMaxWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: () => context.push('/history?tab=penarikan'),
                  style: TextButton.styleFrom(
                    foregroundColor: SibasColors.leaf,
                    minimumSize: const Size(0, 44),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Lihat riwayat penarikan'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 32 + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({
    required double balance,
    required bool balanceReady,
    required bool isSubmitting,
    required bool hasLocation,
    required String? locationName,
  }) {
    return SurfaceCard(
      radius: _cardRadius,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajukan Penarikan', style: _sectionTitle),
            const SizedBox(height: 4),
            Text(
              'Masukkan nominal yang ingin ditarik.',
              style: TextStyle(fontSize: 13, color: SibasColors.muted),
            ),
            if (balanceReady) ...[
              const SizedBox(height: 12),
              _BalanceHint(balance: balance),
            ],
            const SizedBox(height: 20),
            Text(
              'Lokasi Bank Sampah',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: SibasColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const LocationSection(tone: SurfaceTone.subtle),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              enabled: !isSubmitting,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 16, fontFeatures: _tabular),
              onFieldSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              validator: _validateAmount,
              decoration: const InputDecoration(
                labelText: 'Nominal Penarikan',
                prefixText: 'Rp ',
                hintText: 'Contoh: 50000',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorNote(message: _error!),
            ],
            if (locationName != null) ...[
              const SizedBox(height: 12),
              _WithdrawSummary(
                locationName: locationName,
                amountLabel: _amount > 0 ? _currency.format(_amount) : '—',
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (isSubmitting || !balanceReady || !hasLocation)
                    ? null
                    : _submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ajukan Penarikan'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: (isSubmitting || !balanceReady || balance <= 0)
                    ? null
                    : () => _fillAll(balance),
                child: const Text('Tarik Semua'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pengajuan diperiksa admin sebelum dana dicairkan.',
              style: TextStyle(fontSize: 12, color: SibasColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saldo tersedia tepat di atas field, agar tetap terbaca saat hero
/// sudah tergulir ke atas.
class _BalanceHint extends StatelessWidget {
  final double balance;

  const _BalanceHint({required this.balance});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: _noteRadius,
      color: SibasColors.mintWash,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 16,
            color: SibasColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Saldo tersedia: ${_currency.format(balance)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: _tabular,
                color: SibasColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu saldo di dalam hero header.
class _BalancePanel extends StatelessWidget {
  final AsyncValue<double> state;
  final double balance;
  final VoidCallback onRetry;

  const _BalancePanel({
    required this.state,
    required this.balance,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GlassPanel(
        // Panel ini memang menutupi gradien hero, jadi tetap kaca (§7.1).
        tone: GlassTone.hero,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo Tersedia',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            if (state.isLoading && !state.hasValue)
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Memuat saldo...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              )
            else if (state.hasError)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saldo tidak dapat dimuat.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pesanKesalahan(state.error!),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Coba Lagi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              )
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _currency.format(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    fontFeatures: _tabular,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Dana dicairkan setelah pengajuan disetujui admin.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  final String message;

  const _ErrorNote({required this.message});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: _noteRadius,
      color: SibasColors.status.rejectedBackground,
      padding: const EdgeInsets.all(12),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SibasColors.status.badText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Kembali',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
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
    );
  }
}

/// Ringkasan singkat sebelum pengajuan dikirim: nominal dan lokasi
/// pencairan yang sudah dipilih.
class _WithdrawSummary extends StatelessWidget {
  final String locationName;
  final String amountLabel;

  const _WithdrawSummary({
    required this.locationName,
    required this.amountLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: _panelRadius,
      tone: SurfaceTone.subtle,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          _SummaryLine(label: 'Nominal', value: amountLabel, tabular: true),
          const SizedBox(height: 8),
          _SummaryLine(label: 'Lokasi pengambilan', value: locationName),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final bool tabular;

  const _SummaryLine({
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
            style: TextStyle(
              fontSize: 12,
              color: SibasColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: tabular ? _tabular : null,
              color: SibasColors.text,
            ),
          ),
        ),
      ],
    );
  }
}
