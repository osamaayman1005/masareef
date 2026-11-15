import 'dart:async';

import 'package:masareef/domain/models.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/format.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/amount_sheet.dart';
import 'package:masareef/ui/widgets/receipt.dart';
import 'package:masareef/ui/widgets/sheets.dart';
import 'package:material_ui/material_ui.dart';

/// The amount, its currency, and what it cost in EGP. All editable.
class AmountSection extends StatelessWidget {
  const AmountSection({required this.transaction, super.key});

  final LedgerTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final egp = tx.egpCents;
    final note = !tx.isForeign
        ? (tx.amountSetByUser ? 'Changed by you' : 'As the bank sent it')
        : egp == null
            ? 'EGP amount needed before it counts'
            : 'Charged EGP ${formatCents(egp)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Amount'),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.currency} ${formatCents(tx.amountCents)}',
                    style: AppText.strong,
                  ),
                  Text(note, style: AppText.note),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => unawaited(openAmountEditor(context, tx)),
              child: const Text('Edit'),
            ),
          ],
        ),
        if (egp == null) ...[
          const SizedBox(height: 10),
          Callout(
            text: 'Enter what this cost in EGP',
            onTap: () => unawaited(openAmountEditor(context, tx)),
          ),
        ],
      ],
    );
  }
}

/// Opens the amount editor and saves the result. Shared with the Inbox.
Future<void> openAmountEditor(
  BuildContext context,
  LedgerTransaction tx,
) async {
  final controller = AppScope.read(context);
  final edit = await editAmount(
    context,
    transaction: tx,
    snapshot: controller.snapshot,
  );
  if (edit == null) {
    return;
  }
  await controller.editAmount(
    tx.id,
    currency: edit.currency,
    amountCents: edit.amountCents,
    egpCents: edit.egpCents,
  );
}

/// Shows what the transaction is and lets the user correct it, for example
/// a transfer the bank worded like a debit that was really money in.
class TypeSection extends StatelessWidget {
  const TypeSection({required this.transaction, super.key});

  final LedgerTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Type'),
              const SizedBox(height: 2),
              Text(kindLabel(tx.kind), style: AppText.strong),
              Text(
                tx.kindSetByUser ? 'Changed by you' : kindHint(tx.kind),
                style: AppText.note,
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => unawaited(_change(context)),
          child: const Text('Change'),
        ),
      ],
    );
  }

  Future<void> _change(BuildContext context) async {
    final controller = AppScope.read(context);
    final hasSplits = controller.snapshot.splitsOf(transaction.id).isNotEmpty;
    final picked = await pickKind(
      context,
      title: 'What is this really?',
      current: transaction.kind,
      warning: hasSplits
          ? 'Its splits are removed if the new type cannot be split.'
          : null,
    );
    if (picked == null || picked == transaction.kind) {
      return;
    }
    await controller.changeKind(transaction.id, picked);
    if (context.mounted) {
      showMessage(context, 'Now counted as ${kindLabel(picked)}.');
    }
  }
}
