import 'dart:async';

import 'package:masareef/domain/models.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/logic/inbox.dart';
import 'package:masareef/ui/app_scope.dart';
import 'package:masareef/ui/format.dart';
import 'package:masareef/ui/theme.dart';
import 'package:masareef/ui/widgets/receipt.dart';
import 'package:masareef/ui/widgets/sheets.dart';
import 'package:masareef/ui/widgets/unread_message_card.dart';
import 'package:material_ui/material_ui.dart';

/// Things the app could not decide alone. Each answer is remembered.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = AppScope.of(context).inbox;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Inbox', style: AppText.title),
        const SizedBox(height: 4),
        const Text(
          'Things the app could not decide alone. Answer once and it remembers.',
          style: AppText.note,
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const ReceiptPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Inbox is clear', style: AppText.heading),
                SizedBox(height: 4),
                Text(
                  'Every payment has a category and every message was read.',
                  style: AppText.note,
                ),
              ],
            ),
          ),
        for (final item in items) ...[
          switch (item) {
            final MerchantQuestion question => _QuestionCard(
                title: 'What is ${question.name}?',
                detail: '${plural(question.count, 'payment', 'payments')} · '
                    'EGP ${formatCents(question.totalCents)} · '
                    'last on ${formatDay(question.latest.timestamp)}',
                action: 'Choose a category',
                onTap: () => unawaited(_categorizeMerchant(context, question)),
              ),
            UnnamedPayment(:final transaction) => _QuestionCard(
                title: 'What was this payment?',
                detail: '${transactionAmount(transaction)} · '
                    '${formatDayTime(transaction.timestamp)} · '
                    '${transaction.source}',
                action: 'Choose a category',
                onTap: () => unawaited(_categorizeOne(context, transaction)),
              ),
            ForeignCharge(:final transaction) => _QuestionCard(
                title: '${transactionAmount(transaction)} at '
                    '${transactionTitle(transaction)}',
                detail: 'Charged in ${transaction.currency}. '
                    'Enter the EGP amount to count it.',
                action: 'Enter EGP amount',
                onTap: () => unawaited(_confirmEgp(context, transaction)),
              ),
            UnreadMessage(:final message) =>
              UnreadMessageCard(message: message),
          },
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _categorizeMerchant(
    BuildContext context,
    MerchantQuestion question,
  ) async {
    final controller = AppScope.read(context);
    final picked = await pickCategory(
      context,
      title: 'What is ${question.name}?',
      subtitle: 'Past and future payments there go into this category.',
      categories: controller.snapshot.categories,
    );
    if (picked != null) {
      await controller.categorizeMerchant(question.merchantKey, picked);
    }
  }

  Future<void> _categorizeOne(
      BuildContext context, LedgerTransaction tx) async {
    final controller = AppScope.read(context);
    final picked = await pickCategory(
      context,
      title: 'What was this payment?',
      categories: controller.snapshot.categories,
    );
    if (picked != null) {
      await controller.categorizeTransaction(tx.id, picked);
    }
  }

  Future<void> _confirmEgp(BuildContext context, LedgerTransaction tx) async {
    final controller = AppScope.read(context);
    final cents = await askAmount(
      context,
      title: 'What did ${transactionAmount(tx)} cost?',
      hint: 'Check the amount your bank charged in pounds.',
      confirmLabel: 'Save',
    );
    if (cents != null) {
      await controller.confirmEgp(tx.id, cents);
    }
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.detail,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String detail;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.heading),
              const SizedBox(height: 4),
              Text(detail, style: AppText.label),
              const SizedBox(height: 8),
              Text(
                action,
                style: AppText.strong.copyWith(color: AppColors.action),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
