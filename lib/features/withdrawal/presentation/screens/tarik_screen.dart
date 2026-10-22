import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/models/withdrawal_model.dart';
import '../providers/withdrawal_provider.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final _shortDate = DateFormat('dd MMM yyyy', 'id_ID');

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

    final amount = _amount;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _error = null);

    final created =
        await ref.read(withdrawalControllerProvider.notifier).create(amount);
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
  }

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(availableBalanceProvider);
    final withdrawalsState = ref.watch(studentWithdrawalsProvider);
    final isSubmitting = ref.watch(withdrawalControllerProvider).isLoading;

    final balance = balanceState.valueOrNull ?? 0;
    final balanceReady = balanceState.hasValue && !balanceState.hasError;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLine),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ajukan Penarikan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Masukkan nominal yang ingin ditarik.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textInputAction: TextInputAction.done,
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ElevatedButton(
                              onPressed: (isSubmitting || !balanceReady)
                                  ? null
                                  : _submit,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                  horizontal: 8,
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Ajukan Penarikan',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              onPressed: (isSubmitting ||
                                      !balanceReady ||
                                      balance <= 0)
                                  ? null
                                  : () => _fillAll(balance),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                  horizontal: 8,
                                ),
                              ),
                              child: const Text(
                                'Tarik Semua',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pengajuan diperiksa admin sebelum dana dicairkan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Riwayat Penarikan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
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
                child: _HistoryError(
                  onRetry: () => ref.invalidate(studentWithdrawalsProvider),
                ),
              ),
            ],
            data: (items) => items.isEmpty
                ? [
                    const SliverToBoxAdapter(child: _EmptyHistory()),
                  ]
                : [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _WithdrawalTile(withdrawal: items[index]),
                          childCount: items.length,
                        ),
                      ),
                    ),
                  ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
                      minimumSize: const Size(0, 0),
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
      child: Material(
        color: AppColors.cardSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.borderLine),
        ),
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
                        color: AppColors.mintSoftBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.payments_rounded,
                        color: AppColors.primaryMain,
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _shortDate.format(withdrawal.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatusBadge(status: withdrawal.status),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Alasan: $reason',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: const Text(
        'Belum ada pengajuan penarikan.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  final VoidCallback onRetry;

  const _HistoryError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gagal memuat riwayat penarikan.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
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
