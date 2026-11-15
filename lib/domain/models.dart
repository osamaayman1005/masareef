/// Plain data types shared by the parser, storage, logic and UI layers.
library;

/// What a money movement is. The string [dbName] is stored in SQLite and in
/// `patterns.json`, so never rename an existing value.
enum TxKind {
  purchase('purchase'),
  refund('refund'),
  cash('cash'),
  transferOut('transfer_out'),
  transferIn('transfer_in');

  const TxKind(this.dbName);

  final String dbName;

  /// Cash and sent transfers are split by hand into categories.
  bool get isAssignable => this == cash || this == transferOut;

  static TxKind fromDbName(String name) => TxKind.values.firstWhere(
        (kind) => kind.dbName == name,
        orElse: () => throw FormatException('Unknown transaction kind: $name'),
      );
}

/// What happened to an SMS during sync. Stored as [dbName].
enum MessageStatus {
  parsed('parsed'),
  skipped('skipped'),
  failed('failed'),
  ignored('ignored'),
  manual('manual'),
  dismissed('dismissed');

  const MessageStatus(this.dbName);

  final String dbName;

  static MessageStatus fromDbName(String name) =>
      MessageStatus.values.firstWhere(
        (status) => status.dbName == name,
        orElse: () => throw FormatException('Unknown message status: $name'),
      );
}

class ExpenseCategory {
  const ExpenseCategory(
      {required this.id, required this.name, required this.sortOrder});

  final int id;
  final String name;
  final int sortOrder;
}

/// One SMS the app has seen. The [key] makes re-syncing safe: the same SMS
/// always produces the same key, and the database refuses duplicates.
class StoredMessage {
  const StoredMessage({
    required this.key,
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.status,
    this.rule,
  });

  final String key;
  final String sender;
  final String body;
  final DateTime timestamp;
  final MessageStatus status;

  /// Template id that parsed it, skip rule id, or `ignore:<id>`.
  final String? rule;
}

class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.timestamp,
    required this.kind,
    required this.amountCents,
    required this.currency,
    required this.egpCents,
    required this.merchant,
    required this.merchantKey,
    required this.source,
    required this.excluded,
    this.kindSetByUser = false,
    this.messageKey,
    this.categoryId,
    this.card,
  });

  final int id;
  final String? messageKey;
  final DateTime timestamp;
  final TxKind kind;

  /// Amount in [currency].
  final int amountCents;
  final String currency;

  /// Amount in Egyptian pounds. Null until the user confirms a foreign
  /// currency charge, and excluded from totals until then.
  final int? egpCents;
  final String? merchant;

  /// Normalized merchant used for remembered categories. Empty when the SMS
  /// named no merchant.
  final String merchantKey;

  /// Category picked for this payment only. Overrides the merchant rule.
  final int? categoryId;

  /// Bank or wallet that sent the SMS, or `Manual`.
  final String source;
  final String? card;

  /// Excluded from every total (for example a move between own accounts).
  final bool excluded;

  /// The user corrected [kind] by hand. Parser updates never change it back.
  final bool kindSetByUser;
}

/// New transaction before it has an id.
class TransactionDraft {
  const TransactionDraft({
    required this.timestamp,
    required this.kind,
    required this.amountCents,
    required this.currency,
    required this.merchant,
    required this.merchantKey,
    required this.source,
    this.messageKey,
    this.categoryId,
    this.card,
  });

  final String? messageKey;
  final DateTime timestamp;
  final TxKind kind;
  final int amountCents;
  final String currency;
  final String? merchant;
  final String merchantKey;
  final String source;
  final int? categoryId;
  final String? card;
}

/// Part of a cash withdrawal or sent transfer assigned to a category.
class Split {
  const Split({
    required this.id,
    required this.transactionId,
    required this.categoryId,
    required this.amountCents,
  });

  final int id;
  final int transactionId;
  final int categoryId;
  final int amountCents;
}

/// A message format the user chose to skip from now on.
class IgnoreRule {
  const IgnoreRule({
    required this.id,
    required this.sender,
    required this.signature,
    required this.sample,
    required this.createdAt,
  });

  final int id;
  final String sender;
  final String signature;
  final String sample;
  final DateTime createdAt;
}

/// Inclusive range of calendar days.
class DayRange {
  DayRange(DateTime first, DateTime last)
      : start = _day(first.isBefore(last) ? first : last),
        end = _day(first.isBefore(last) ? last : first);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime moment) {
    final day = _day(moment);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

/// Everything the UI shows, loaded in one read.
class LedgerSnapshot {
  const LedgerSnapshot({
    required this.categories,
    required this.merchantRules,
    required this.transactions,
    required this.splits,
    required this.messages,
    required this.ignoreRules,
  });

  static const LedgerSnapshot empty = LedgerSnapshot(
    categories: [],
    merchantRules: {},
    transactions: [],
    splits: [],
    messages: [],
    ignoreRules: [],
  );

  final List<ExpenseCategory> categories;

  /// merchantKey -> categoryId
  final Map<String, int> merchantRules;
  final List<LedgerTransaction> transactions;
  final List<Split> splits;

  /// Only messages that need attention or explain a decision:
  /// failed, ignored and dismissed. Parsed ones live on their transaction.
  final List<StoredMessage> messages;
  final List<IgnoreRule> ignoreRules;

  String categoryName(int id) {
    for (final category in categories) {
      if (category.id == id) {
        return category.name;
      }
    }
    return 'Deleted category';
  }

  /// Category used for a purchase or refund: its own pick, else the
  /// remembered merchant rule, else null.
  int? effectiveCategory(LedgerTransaction tx) =>
      tx.categoryId ?? merchantRules[tx.merchantKey];

  List<Split> splitsOf(int transactionId) =>
      splits.where((split) => split.transactionId == transactionId).toList();

  int assignedCents(int transactionId) =>
      splitsOf(transactionId).fold(0, (sum, split) => sum + split.amountCents);
}
