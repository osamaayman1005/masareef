import 'dart:async';

import 'package:masareef/domain/models.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/parser/text_tools.dart';
import 'package:masareef/state/app_controller.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/format.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/amount_sheet.dart';
import 'package:masareef/ui/widgets/receipt.dart';
import 'package:masareef/ui/widgets/sheets.dart';
import 'package:masareef/ui/widgets/split_editor.dart';
import 'package:material_ui/material_ui.dart';

/// Details of one transaction: category, splits, and the original SMS.
class TransactionScreen extends StatelessWidget {
  const TransactionScreen({required this.transactionId, super.key});

  final int transactionId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final matches =
        controller.snapshot.transactions.where((tx) => tx.id == transactionId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This entry no longer exists.')),
      );
    }
    final tx = matches.first;
    final card = tx.card;

    return Scaffold(
      appBar: AppBar(title: Text(kindLabel(tx.kind))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(transactionTitle(tx), style: AppText.title),
          const SizedBox(height: 4),
          Text(
            [
              transactionAmount(tx),
              formatDayTime(tx.timestamp),
              tx.source,
              if (card != null) '••$card',
            ].join(' · '),
            style: AppText.note,
          ),
          const SizedBox(height: 16),
          _TypeSection(transaction: tx),
          const SizedBox(height: 16),
          _AmountSection(transaction: tx),
          const SizedBox(height: 16),
          if (tx.kind.isAssignable && tx.egpCents != null)
            SplitEditor(transaction: tx)
          else if (tx.kind == TxKind.purchase || tx.kind == TxKind.refund)
            _CategorySection(transaction: tx),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Leave out of totals', style: AppText.strong),
            subtitle: const Text(
              'For moves between your own accounts.',
              style: AppText.note,
            ),
            value: tx.excluded,
            onChanged: (value) => unawaited(
              AppScope.read(context).setExcluded(tx.id, excluded: value),
            ),
          ),
          const SizedBox(height: 16),
          _OriginalSms(messageKey: tx.messageKey),
        ],
      ),
    );
  }

}

/// The amount, its currency, and what it cost in EGP. All editable.
class _AmountSection extends StatelessWidget {
  const _AmountSection({required this.transaction});

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
class _TypeSection extends StatelessWidget {
  const _TypeSection({required this.transaction});

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

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.transaction});

  final LedgerTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final tx = transaction;
    final category = controller.snapshot.effectiveCategory(tx);
    final merchant = displayMerchant(tx.merchant ?? '');

    return ReceiptPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Category'),
          const SizedBox(height: 4),
          Text(
            category == null
                ? 'No category yet'
                : controller.snapshot.categoryName(category),
            style: AppText.heading,
          ),
          if (tx.categoryId != null)
            const Text('Set for this payment only.', style: AppText.note),
          const SizedBox(height: 12),
          if (tx.merchantKey.isNotEmpty)
            FilledButton(
              onPressed: () =>
                  unawaited(_pick(context, controller, allAtMerchant: true)),
              child: Text('Set for everything at $merchant'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () =>
                unawaited(_pick(context, controller, allAtMerchant: false)),
            child: const Text('Set for this payment only'),
          ),
          if (tx.categoryId != null && tx.merchantKey.isNotEmpty)
            TextButton(
              onPressed: () =>
                  unawaited(controller.categorizeTransaction(tx.id, null)),
              child: Text('Use the $merchant category again'),
            ),
        ],
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    AppController controller, {
    required bool allAtMerchant,
  }) async {
    final picked = await pickCategory(
      context,
      title: allAtMerchant
          ? 'What is ${displayMerchant(transaction.merchant ?? '')}?'
          : 'What was this payment?',
      subtitle: allAtMerchant
          ? 'Past and future payments there go into this category.'
          : null,
      categories: controller.snapshot.categories,
    );
    if (picked == null) {
      return;
    }
    if (allAtMerchant) {
      await controller.categorizeMerchant(transaction.merchantKey, picked);
      if (transaction.categoryId != null) {
        await controller.categorizeTransaction(transaction.id, null);
      }
    } else {
      await controller.categorizeTransaction(transaction.id, picked);
    }
  }
}

class _OriginalSms extends StatefulWidget {
  const _OriginalSms({required this.messageKey});

  final String? messageKey;

  @override
  State<_OriginalSms> createState() => _OriginalSmsState();
}

class _OriginalSmsState extends State<_OriginalSms> {
  Future<String?>? _body;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = widget.messageKey;
    _body ??=
        key == null ? null : AppScope.read(context).store.messageBody(key);
  }

  @override
  Widget build(BuildContext context) {
    final body = _body;
    if (body == null) {
      return const Text('Added by hand.', style: AppText.note);
    }
    return FutureBuilder<String?>(
      future: body,
      builder: (context, snapshot) {
        final text = snapshot.data;
        if (text == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Original message'),
            const SizedBox(height: 6),
            Container(
              color: AppColors.quote,
              padding: const EdgeInsets.all(12),
              child: SelectableText(text, style: AppText.sms),
            ),
          ],
        );
      },
    );
  }
}
