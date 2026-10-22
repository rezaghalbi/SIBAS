import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/withdrawal_provider.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Rincian satu pengajuan penarikan beserta riwayat proses dan aksi admin.
class WithdrawalDetailScreen extends ConsumerWidget {
  final String withdrawalId;

  const WithdrawalDetailScreen({
    super.key,
    required this.withdrawalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(withdrawalDetailProvider(withdrawalId));
    final row = detailState.valueOrNull;
    final isAdmin = ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeroHeader(
              title: 'Detail Penarikan',
              subtitle: 'Rincian pengajuan pencairan saldo',
              trailing: const _BackButton(),
              bottomContent: row == null
                  ? null
                  : _SummaryPanel(
                      amount: _num(row['amount']),
                      status: _text(row['status']),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverToBoxAdapter(
              child: detailState.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, __) => _ErrorBox(
                  message: pesanKesalahan(error),
                  onRetry: () =>
                      ref.invalidate(withdrawalDetailProvider(withdrawalId)),
                ),
                data: (data) => data == null
                    ? const _NotFoundBox()
                    : _DetailBody(
                        row: data,
                        withdrawalId: withdrawalId,
                        isAdmin: isAdmin,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double? _num(dynamic value) => value is num ? value.toDouble() : null;

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

Map? _map(dynamic value) => value is Map ? value : null;

String _statusLabel(String status) => switch (status.toUpperCase()) {
      'APPROVED' => 'Disetujui',
      'REJECTED' => 'Ditolak',
      'EXPIRED' => 'Kedaluwarsa',
      'PENDING' => 'Menunggu',
      _ => 'Status diperbarui',
    };

Color _statusColor(String status) => switch (status.toUpperCase()) {
      'APPROVED' => AppColors.statusApprovedText,
      'REJECTED' => AppColors.statusRejectedText,
      'EXPIRED' => AppColors.statusExpired,
      _ => AppColors.statusPendingText,
    };

/// Ringkasan nominal dan status di dalam hero header.
class _SummaryPanel extends StatelessWidget {
  final double? amount;
  final String? status;

  const _SummaryPanel({required this.amount, required this.status});

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
              'Nominal Penarikan',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currency.format(amount ?? 0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            StatusBadge(status: status ?? 'PENDING'),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> row;
  final String withdrawalId;
  final bool isAdmin;

  const _DetailBody({
    required this.row,
    required this.withdrawalId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    final status = _text(row['status']) ?? 'PENDING';
    final isPending = status.toUpperCase() == 'PENDING';
    final createdAt = _date(row['created_at']);
    final verifiedAt = _date(row['verified_at']);
    final mahasiswa = _map(row['mahasiswa']);
    final verifikator = _map(row['verifikator']);
    final rejectionReason = _text(row['rejection_reason']);

    final studentName = _text(mahasiswa?['full_name']) ?? '-';
    final studentNim = _text(mahasiswa?['nim']);
    final verifierName = _text(verifikator?['full_name']);

    final verifierLabel = switch (status.toUpperCase()) {
      'APPROVED' => 'Disetujui oleh',
      'REJECTED' => 'Ditolak oleh',
      _ => 'Diverifikasi oleh',
    };

    final audits = <Map>[];
    final rawAudits = row['audits'];
    if (rawAudits is List) {
      for (final entry in rawAudits) {
        if (entry is Map) audits.add(entry);
      }
    }
    audits.sort((a, b) {
      final first = _date(a['created_at']);
      final second = _date(b['created_at']);
      if (first == null || second == null) return 0;
      return first.compareTo(second);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rincian Pengajuan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Divider(height: 20, color: AppColors.borderLine),
              _DetailField(
                label: 'Tanggal Diajukan',
                value: createdAt == null ? '-' : dateFormat.format(createdAt),
              ),
              _DetailField(
                label: 'Pengaju',
                value: studentName,
                secondary: studentNim == null ? null : 'NIM $studentNim',
              ),
              if (verifiedAt != null || verifierName != null)
                _DetailField(
                  label: verifierLabel,
                  value: verifierName ?? '-',
                  secondary:
                      verifiedAt == null ? null : dateFormat.format(verifiedAt),
                ),
            ],
          ),
        ),
        if (rejectionReason != null) ...[
          const SizedBox(height: 16),
          _NoteBox(
            icon: Icons.error_outline_rounded,
            title: 'Alasan Penolakan',
            text: rejectionReason,
          ),
        ],
        if (isAdmin && isPending) ...[
          const SizedBox(height: 16),
          _ApprovalActions(
            withdrawalId: withdrawalId,
            amount: _num(row['amount']) ?? 0,
          ),
        ],
        const SizedBox(height: 24),
        _Timeline(audits: audits),
      ],
    );
  }
}

/// Label-kecil di atas nilai; aman untuk lebar 360 px.
class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  final String? secondary;

  const _DetailField({
    required this.label,
    required this.value,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 2),
            Text(
              secondary!,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Timeline vertikal dari audit penarikan (urutan kronologis).
class _Timeline extends StatelessWidget {
  final List<Map> audits;

  const _Timeline({required this.audits});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Proses',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 20, color: AppColors.borderLine),
          if (audits.isEmpty)
            const Text(
              'Belum ada catatan proses.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            for (var index = 0; index < audits.length; index++)
              _TimelineItem(
                audit: audits[index],
                isLast: index == audits.length - 1,
              ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map audit;
  final bool isLast;

  const _TimelineItem({required this.audit, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final status = _text(audit['to_status']) ?? '';
    final color = _statusColor(status);
    final note = _text(audit['note']);
    final actor = _text(audit['actor_name']) ?? 'Sistem';
    final at = _date(audit['created_at']);
    final meta = at == null
        ? actor
        : '$actor • ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(at)}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.borderLine),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      note,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol verifikasi admin untuk pengajuan yang masih menunggu.
class _ApprovalActions extends ConsumerStatefulWidget {
  final String withdrawalId;
  final double amount;

  const _ApprovalActions({
    required this.withdrawalId,
    required this.amount,
  });

  @override
  ConsumerState<_ApprovalActions> createState() => _ApprovalActionsState();
}

class _ApprovalActionsState extends ConsumerState<_ApprovalActions> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    final ok = await action();
    if (!mounted) return;

    if (ok) {
      // Biarkan tombol nonaktif sampai detail termuat ulang.
      ref.invalidate(withdrawalDetailProvider(widget.withdrawalId));
      messenger.showSnackBar(SnackBar(content: Text(success)));
      return;
    }

    setState(() => _busy = false);
    final failure = ref.read(withdrawalControllerProvider).error;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? 'Tindakan gagal dikirim. Coba lagi.'
              : pesanKesalahan(failure),
        ),
      ),
    );
  }

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Setujui Penarikan'),
        content: Text(
          'Setujui penarikan ${_currency.format(widget.amount)}? '
          'Saldo mahasiswa akan dikurangi sebesar nominal tersebut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run(
      () => ref
          .read(withdrawalControllerProvider.notifier)
          .approve(widget.withdrawalId),
      'Penarikan disetujui.',
    );
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || !mounted) return;

    await _run(
      () => ref
          .read(withdrawalControllerProvider.notifier)
          .reject(widget.withdrawalId, reason),
      'Penarikan ditolak.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tindakan Admin',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Periksa data pengajuan sebelum menyetujui atau menolak.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _approve,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Setujui'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Tolak'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Alasan penolakan wajib diisi.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tolak Penarikan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tulis alasan agar mahasiswa tahu mengapa pengajuan ditolak.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Contoh: Nomor rekening belum lengkap',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Tolak'),
        ),
      ],
    );
  }
}

class _NoteBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _NoteBox({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _NotFoundBox extends StatelessWidget {
  const _NotFoundBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 32, color: AppColors.textMuted),
          SizedBox(height: 10),
          Text(
            'Penarikan tidak ditemukan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
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
