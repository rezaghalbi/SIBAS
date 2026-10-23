import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/theme.dart';
import '../providers/withdrawal_provider.dart';
import '../../../../core/theme/sibas_colors.dart';

const String _genericError =
    'Pengajuan gagal dikirim. Periksa koneksi lalu coba lagi.';

/// Pesan apa adanya hanya dipakai bila berasal dari server (Bahasa Indonesia).
/// Error teknis/transport selalu diganti pesan generik.
String _safeMessage(Object? error) {
  final raw = error is PostgrestException ? error.message : error?.toString();
  if (raw == null) return _genericError;

  final text = raw.trim();
  final looksIndonesian = RegExp(
    r'\b(saldo|penarikan|nominal|tidak|belum|minimal|maksimal|gagal|wajib|'
    r'harus|ditolak|kurang|pengajuan|dana|verifikasi|sedang)\b',
    caseSensitive: false,
  ).hasMatch(text);
  final looksTechnical = RegExp(
    r'(exception|postgrest|socket|error|relation|violates|constraint|http|null)',
    caseSensitive: false,
  ).hasMatch(text);

  if (looksIndonesian && !looksTechnical && text.length <= 200) return text;
  return _genericError;
}

/// Membuka sheet penarikan saldo.
Future<void> showWithdrawSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTheme.bottomSheetRadius),
      ),
    ),
    builder: (_) => const WithdrawSheet(),
  );
}

/// Form pengajuan penarikan saldo; error tampil permanen di dalam sheet.
class WithdrawSheet extends ConsumerStatefulWidget {
  const WithdrawSheet({super.key});

  @override
  ConsumerState<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<WithdrawSheet> {
  final _controller = TextEditingController();
  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _amount {
    final digits = _controller.text.replaceAll('.', '');
    return double.tryParse(digits) ?? 0;
  }

  Future<void> _submit(double balance) async {
    final amount = _amount;

    if (amount <= 0) {
      setState(() => _error = 'Masukkan nominal penarikan lebih dari 0.');
      return;
    }
    if (amount > balance) {
      setState(
        () => _error =
            'Nominal melebihi saldo tersedia (${_currency.format(balance)}).',
      );
      return;
    }

    setState(() => _error = null);
    final messenger = ScaffoldMessenger.of(context);
    final created =
        await ref.read(withdrawalControllerProvider.notifier).create(amount);
    if (!mounted) return;

    if (created == null) {
      setState(() {
        _error = _safeMessage(ref.read(withdrawalControllerProvider).error);
      });
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Pengajuan penarikan terkirim. Menunggu verifikasi admin.'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(availableBalanceProvider).valueOrNull ?? 0.0;
    final isSubmitting = ref.watch(withdrawalControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SibasColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tarik Saldo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SibasColors.text,
                  ),
                ),
              ),
              IconButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: SibasColors.muted),
                tooltip: 'Tutup',
              ),
            ],
          ),
          Text(
            'Saldo tersedia ${_currency.format(balance)}',
            style: TextStyle(fontSize: 13, color: SibasColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !isSubmitting,
            keyboardType: TextInputType.number,
            inputFormatters: [const _ThousandsFormatter()],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(balance),
            decoration: const InputDecoration(
              labelText: 'Nominal Penarikan',
              prefixText: 'Rp ',
              hintText: 'Contoh: 50.000',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pengajuan diproses admin. Dana dicairkan setelah disetujui.',
            style: TextStyle(fontSize: 12, color: SibasColors.muted),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
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
                      _error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: SibasColors.status.badText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () => _submit(balance),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Kirim Pengajuan'),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

/// Format ribuan saat mengetik; hanya digit yang diterima.
class _ThousandsFormatter extends TextInputFormatter {
  const _ThousandsFormatter();

  static final _digits = RegExp(r'[^0-9]');
  static final _group = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(_digits, '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > 12) digits = digits.substring(0, 12);

    final formatted = _group.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
