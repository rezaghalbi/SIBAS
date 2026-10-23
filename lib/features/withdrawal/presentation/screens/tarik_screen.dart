import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../bank_location/domain/models/bank_location_model.dart';
import '../../../bank_location/presentation/providers/bank_location_provider.dart';
import '../../domain/models/withdrawal_model.dart';
import '../providers/withdrawal_provider.dart';
import '../widgets/withdraw_qr_sheet.dart';
import '../../../../core/theme/sibas_colors.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final _shortDate = DateFormat('dd MMM yyyy', 'id_ID');

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
const double _sheetRadius = 28;

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
    final withdrawalsState = ref.watch(studentWithdrawalsProvider);
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
                padding: EdgeInsets.only(top: 24, bottom: 12),
                child: Text('Riwayat Penarikan', style: _sectionTitle),
              ),
            ),
          ),
          ...withdrawalsState.when<List<Widget>>(
            loading: () => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
            error: (_, __) => [
              SliverToBoxAdapter(
                child: ContentWidth(
                  maxWidth: _contentMaxWidth,
                  child: _HistoryError(
                    onRetry: () => ref.invalidate(studentWithdrawalsProvider),
                  ),
                ),
              ),
            ],
            data: (items) => items.isEmpty
                ? [
                    const SliverToBoxAdapter(
                      child: ContentWidth(
                        maxWidth: _contentMaxWidth,
                        child: _EmptyHistory(),
                      ),
                    ),
                  ]
                : [
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ContentWidth(
                          maxWidth: _contentMaxWidth,
                          child: _WithdrawalTile(
                            withdrawal: items[index],
                          ),
                        ),
                        childCount: items.length,
                      ),
                    ),
                  ],
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
            const _LocationSection(tone: SurfaceTone.subtle),
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

/// Satu baris riwayat penarikan; ketuk untuk membuka detail.
class _WithdrawalTile extends StatelessWidget {
  final WithdrawalModel withdrawal;

  const _WithdrawalTile({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    final reason = withdrawal.rejectionReason;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        radius: _cardRadius,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(_cardRadius),
          child: InkWell(
            onTap: () => context.push('/withdrawal/${withdrawal.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: SibasColors.mintWash,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.payments_rounded,
                          color: SibasColors.leaf,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currency.format(withdrawal.amount),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFeatures: _tabular,
                                color: SibasColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _shortDate.format(withdrawal.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: SibasColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: SibasColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StatusBadge(status: withdrawal.status),
                  if (withdrawal.isPending &&
                      (withdrawal.qrToken?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => showWithdrawQrSheet(
                          context,
                          token: withdrawal.qrToken!,
                          amount: withdrawal.amount,
                          status: withdrawal.status,
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          foregroundColor: SibasColors.leaf,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_rounded, size: 18),
                        label: const Text('Tampilkan QR'),
                      ),
                    ),
                  ],
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Alasan: $reason',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SibasColors.status.badText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: _cardRadius,
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Text(
        'Belum ada pengajuan penarikan.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: SibasColors.muted),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  final VoidCallback onRetry;

  const _HistoryError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: _panelRadius,
      color: SibasColors.status.rejectedBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gagal memuat riwayat penarikan.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SibasColors.status.badText,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: TextButton.styleFrom(foregroundColor: SibasColors.status.badText),
            ),
          ),
        ],
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

/// Blok pemilih lokasi bank sampah.
///
/// Status muat dan galat dibaca dari [bankLocationsProvider]; daftar lokasi
/// aktif diturunkan lewat [activeLocationsProvider] yang bernilai kosong saat
/// memuat, jadi tidak boleh dipakai sendirian untuk mendeteksi loading.
class _LocationSection extends ConsumerStatefulWidget {
  final SurfaceTone tone;

  const _LocationSection({this.tone = SurfaceTone.card});

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
      radius: _panelRadius,
      tone: widget.tone,
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
      return Padding(
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
                style: TextStyle(fontSize: 13, color: SibasColors.muted),
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
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: SibasColors.status.badText,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lokasi belum dipilih. Pilih lokasi untuk melanjutkan.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SibasColors.status.badText,
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
              color: SibasColors.mintWash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.place_rounded,
              size: 20,
              color: kosong ? SibasColors.muted : SibasColors.leaf,
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
                        ? SibasColors.muted
                        : SibasColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  keterangan,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: SibasColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (tetap)
            const _TerpilihBadge()
          else
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: SibasColors.muted,
            ),
        ],
      ),
    );

    if (onTap == null) return isi;

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_panelRadius),
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
        color: SibasColors.leaf.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titik penanda status (§2): jangan andalkan warna saja.
          SizedBox(
            width: 5,
            height: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SibasColors.leaf,
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
              color: SibasColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tidak ada lokasi aktif: pencairan belum bisa diajukan.
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
            Icon(
              Icons.location_off_rounded,
              size: 20,
              color: SibasColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum ada lokasi bank sampah aktif.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SibasColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Setoran dan penarikan belum bisa diajukan sampai admin '
                    'mengaktifkan lokasi.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: SibasColors.muted,
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: SibasColors.status.badText,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lokasi bank sampah gagal dimuat.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SibasColors.status.badText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Periksa koneksi lalu coba lagi.',
          style: TextStyle(fontSize: 12, color: SibasColors.muted),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: SibasColors.leaf,
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
                    color: SibasColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pilih Lokasi Bank Sampah',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.15,
                            color: SibasColors.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: SibasColors.muted,
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
            ? SibasColors.leaf.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(_panelRadius),
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
                    color: SibasColors.mintWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.place_rounded,
                    size: 18,
                    color: SibasColors.leaf,
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SibasColors.text,
                        ),
                      ),
                      if (alamat.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          alamat,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: SibasColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dipilih) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: SibasColors.leaf,
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
