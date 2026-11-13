import 'package:masareef/domain/models.dart';
import 'package:masareef/parser/text_tools.dart';

sealed class InboxItem {
  const InboxItem();
}

/// A merchant seen in payments that has no category yet.
final class MerchantQuestion extends InboxItem {
  const MerchantQuestion({
    required this.merchantKey,
    required this.name,
    required this.count,
    required this.totalCents,
    required this.latest,
  });

  final String merchantKey;
  final String name;
  final int count;
  final int totalCents;
  final LedgerTransaction latest;
}

/// A payment whose SMS named no merchant. Categorized on its own.
final class UnnamedPayment extends InboxItem {
  const UnnamedPayment(this.transaction);

  final LedgerTransaction transaction;
}

/// A charge in another currency waiting for its EGP amount.
final class ForeignCharge extends InboxItem {
  const ForeignCharge(this.transaction);

  final LedgerTransaction transaction;
}

/// An SMS from a bank that the parser could not read.
final class UnreadMessage extends InboxItem {
  const UnreadMessage(this.message);

  final StoredMessage message;
}

/// Everything that needs the user, oldest unread messages last.
List<InboxItem> buildInbox(LedgerSnapshot snapshot) {
  final merchants = <String, List<LedgerTransaction>>{};
  final unnamed = <UnnamedPayment>[];
  final foreign = <ForeignCharge>[];

  for (final tx in snapshot.transactions) {
    if (tx.excluded) {
      continue;
    }
    if (tx.egpCents == null) {
      foreign.add(ForeignCharge(tx));
    }
    final needsCategory = (tx.kind == TxKind.purchase ||
            tx.kind == TxKind.refund) &&
        snapshot.effectiveCategory(tx) == null;
    if (!needsCategory) {
      continue;
    }
    if (tx.merchantKey.isEmpty) {
      unnamed.add(UnnamedPayment(tx));
    } else {
      merchants.putIfAbsent(tx.merchantKey, () => []).add(tx);
    }
  }

  final questions = [
    for (final entry in merchants.entries)
      MerchantQuestion(
        merchantKey: entry.key,
        name: displayMerchant(entry.value.first.merchant ?? entry.key),
        count: entry.value.length,
        totalCents:
            entry.value.fold(0, (sum, tx) => sum + (tx.egpCents ?? 0)),
        latest: entry.value.first,
      ),
  ]..sort((a, b) => b.count.compareTo(a.count));

  return [
    ...questions,
    ...unnamed,
    ...foreign,
    for (final message in snapshot.messages)
      if (message.status == MessageStatus.failed) UnreadMessage(message),
  ];
}
