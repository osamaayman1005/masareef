import 'package:masareef/domain/models.dart';
import 'package:masareef/ui/format.dart';
import 'package:masareef/ui/screens/transaction_screen.dart';
import 'package:masareef/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

/// One row in a list of transactions. Opens the detail screen.
class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, super.key});

  final LedgerTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final card = tx.card;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TransactionScreen(transactionId: tx.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transactionTitle(tx), style: AppText.strong),
                  const SizedBox(height: 2),
                  Text(
                    [
                      formatDayTime(tx.timestamp),
                      tx.source,
                      if (card != null) '••$card',
                    ].join(' · '),
                    style: AppText.note,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              tx.kind == TxKind.refund
                  ? '−${transactionAmount(tx)}'
                  : transactionAmount(tx),
              style: AppText.amount,
            ),
          ],
        ),
      ),
    );
  }
}
