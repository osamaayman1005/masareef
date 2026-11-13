import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masareef/domain/models.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/format.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/receipt.dart';
import 'package:masareef/ui/widgets/sheets.dart';

/// A bank SMS the parser could not read, with the three ways to resolve it.
class UnreadMessageCard extends StatelessWidget {
  const UnreadMessageCard({required this.message, super.key});

  final StoredMessage message;

  @override
  Widget build(BuildContext context) {
    final rtl = RegExp('[؀-ۿ]').hasMatch(message.body);
    return ReceiptPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            'Could not read · ${message.sender} · ${formatDay(message.timestamp)}',
          ),
          const SizedBox(height: 8),
          Container(
            color: AppColors.quote,
            padding: const EdgeInsets.all(12),
            child: Text(
              message.body,
              style: AppText.sms,
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                  onPressed: () => unawaited(_ignore(context)),
                  child: const Text('Ignore this format'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => unawaited(_enter(context)),
                  child: const Text('It was money'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => unawaited(AppScope.read(context).dismiss(message)),
            child: const Text('Not money, hide only this one'),
          ),
          const Text(
            'Ignoring skips every future message worded like this one, '
            'even when dates or links change. Payments are never ignored.',
            style: AppText.note,
          ),
        ],
      ),
    );
  }

  Future<void> _ignore(BuildContext context) async {
    await AppScope.read(context).ignoreFormat(message);
    if (context.mounted) {
      showMessage(context, 'Ignored. Undo it from Log › Ignored formats.');
    }
  }

  Future<void> _enter(BuildContext context) async {
    final controller = AppScope.read(context);
    final kind = await showModalBottomSheet<TxKind>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('What was it?', style: AppText.heading),
              const SizedBox(height: 12),
              for (final option in TxKind.values) ...[
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, option),
                  child: Text(kindLabel(option)),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
    if (kind == null || !context.mounted) {
      return;
    }
    final cents = await askAmount(
      context,
      title: kindLabel(kind),
      confirmLabel: 'Next',
    );
    if (cents == null || !context.mounted) {
      return;
    }
    int? categoryId;
    if (kind == TxKind.purchase || kind == TxKind.refund) {
      categoryId = await pickCategory(
        context,
        title: 'Which category?',
        categories: controller.snapshot.categories,
      );
      if (categoryId == null) {
        return;
      }
    }
    await controller.enterManually(
      message,
      kind: kind,
      cents: cents,
      categoryId: categoryId,
    );
  }
}
