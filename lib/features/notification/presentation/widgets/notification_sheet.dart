import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../../history/domain/models/transaction_model.dart';
import '../../../history/presentation/providers/transaction_provider.dart';
import '../../../withdrawal/domain/models/withdrawal_model.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../../../../core/theme/sibas_colors.dart';

/// Lembar notifikasi yang diturunkan dari transaksi & penarikan terbaru.
///
/// Tanpa tabel notifikasi / status "sudah dibaca": semua data dibaca langsung
/// dari provider yang sudah ada.
Future<void> showNotificationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: SibasColors.scrim,
    builder: (sheetContext) => _NotificationSheet(
      onOpenTransaction: (transactionId) {
        Navigator.of(sheetContext).pop();
        context.push('/transaction/$transactionId');
      },
    ),
  );
}

class _NotificationSheet extends ConsumerWidget {
  final ValueChanged<String> onOpenTransaction;

  const _NotificationSheet({required this.onOpenTransaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(recentTransactionsProvider);
    final withdrawals = ref.watch(studentWithdrawalsProvider);

    final items = _buildItems(
      transactions.valueOrNull ?? const <TransactionModel>[],
      withdrawals.valueOrNull ?? const <WithdrawalModel>[],
    );
    final isLoading = transactions.isLoading || withdrawals.isLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: GlassPanel(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: SibasColors.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SibasColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, size: 20, color: SibasColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: isLoading && items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : items.isEmpty
                        ? const _EmptyNotifications()
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(bottom: 4),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _NotificationTile(
                                item: item,
                                onTap: item.transactionId == null
                                    ? null
                                    : () => onOpenTransaction(item.transactionId!),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gabungan transaksi + penarikan, urut terbaru, maksimal 20 item.
List<_AppNotification> _buildItems(
  List<TransactionModel> transactions,
  List<WithdrawalModel> withdrawals,
) {
  final currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  final items = <_AppNotification>[];

  for (final tx in transactions) {
    final status = tx.status.toUpperCase();
    final detail = tx.categoryName;
    switch (status) {
      case 'PENDING':
        items.add(_AppNotification(
          icon: Icons.hourglass_top_rounded,
          color: SibasColors.status.pendingText,
          background: SibasColors.status.pendingBackground,
          title: 'Menunggu verifikasi di bank sampah',
          detail: detail,
          time: tx.createdAt,
          transactionId: tx.id,
        ));
        break;
      case 'APPROVED':
        final amount = tx.finalAmount ?? 0;
        items.add(_AppNotification(
          icon: Icons.check_circle_outline_rounded,
          color: SibasColors.status.approvedText,
          background: SibasColors.status.approvedBackground,
          title: amount > 0
              ? 'Setoran disetujui +${currency.format(amount)}'
              : 'Setoran disetujui',
          detail: amount > 0 ? detail : '${tx.weight.toStringAsFixed(1)} kg • $detail',
          time: tx.createdAt,
          transactionId: tx.id,
        ));
        break;
      case 'REJECTED':
        final reason = tx.rejectionReason?.trim();
        items.add(_AppNotification(
          icon: Icons.cancel_outlined,
          color: SibasColors.status.rejectedText,
          background: SibasColors.status.rejectedBackground,
          title: 'Setoran ditolak',
          detail: (reason == null || reason.isEmpty) ? detail : reason,
          time: tx.createdAt,
          transactionId: tx.id,
        ));
        break;
      case 'EXPIRED':
        items.add(_AppNotification(
          icon: Icons.timer_off_outlined,
          color: SibasColors.status.neutralText,
          background: SibasColors.mintWash,
          title: 'QR kedaluwarsa',
          detail: detail,
          time: tx.createdAt,
          transactionId: tx.id,
        ));
        break;
    }
  }

  for (final withdrawal in withdrawals) {
    final status = withdrawal.status.toUpperCase();
    final amount = currency.format(withdrawal.amount);
    final reason = withdrawal.rejectionReason?.trim();
    final isRejected = status == 'REJECTED';

    items.add(_AppNotification(
      icon: isRejected ? Icons.money_off_rounded : Icons.account_balance_wallet_outlined,
      color: isRejected
          ? SibasColors.status.rejectedText
          : (status == 'APPROVED' ? SibasColors.status.approvedText : SibasColors.status.pendingText),
      background: isRejected
          ? SibasColors.status.rejectedBackground
          : (status == 'APPROVED' ? SibasColors.status.approvedBackground : SibasColors.status.pendingBackground),
      title: isRejected
          ? 'Penarikan $amount ditolak'
          : status == 'APPROVED'
              ? 'Penarikan $amount disetujui'
              : 'Penarikan $amount menunggu verifikasi',
      detail: isRejected && reason != null && reason.isNotEmpty ? reason : null,
      time: withdrawal.createdAt,
    ));
  }

  items.sort((a, b) => b.time.compareTo(a.time));
  return items.take(20).toList();
}

class _AppNotification {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String? detail;
  final DateTime time;
  final String? transactionId;

  const _AppNotification({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.time,
    this.detail,
    this.transactionId,
  });
}

class _NotificationTile extends StatelessWidget {
  final _AppNotification item;
  final VoidCallback? onTap;

  const _NotificationTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final detail = item.detail;

    final content = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: item.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SibasColors.text,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: SibasColors.muted),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(item.time.toLocal()),
                  style: TextStyle(fontSize: 10.5, color: SibasColors.muted),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Icon(Icons.chevron_right_rounded, size: 18, color: SibasColors.muted),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined, size: 36, color: SibasColors.muted),
          SizedBox(height: 10),
          Text(
            'Belum ada notifikasi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SibasColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
