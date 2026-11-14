import 'package:masareef/domain/models.dart';

enum LineKind {
  category,
  uncategorized,
  unassignedCash,
  unassignedTransfer,
  moneyIn,
}

class SpendingLine {
  const SpendingLine({
    required this.kind,
    required this.label,
    required this.cents,
    required this.count,
    this.categoryId,
  });

  final LineKind kind;
  final String label;
  final int cents;
  final int count;
  final int? categoryId;
}

class SpendingSummary {
  const SpendingSummary({
    required this.totalCents,
    required this.lines,
    required this.incomeCents,
    required this.incomeCount,
  });

  final int totalCents;

  /// Largest first. Category lines, then waiting and unassigned lines.
  final List<SpendingLine> lines;

  /// Money received. Never counted as spending.
  final int incomeCents;
  final int incomeCount;

  /// The money-in total as a line, so it opens like any other.
  SpendingLine get incomeLine => SpendingLine(
        kind: LineKind.moneyIn,
        label: 'Money in',
        cents: incomeCents,
        count: incomeCount,
      );
}

/// Totals for [range]. Pure function of the snapshot, so it is easy to test
/// and impossible to double count: every transaction is visited once.
SpendingSummary summarize(LedgerSnapshot snapshot, DayRange range) {
  final byCategory = <int, int>{};
  final countByCategory = <int, int>{};
  var uncategorized = 0;
  var uncategorizedCount = 0;
  var cash = 0;
  var cashCount = 0;
  var transfers = 0;
  var transferCount = 0;
  var income = 0;
  var incomeCount = 0;

  void addToCategory(int id, int cents) {
    byCategory[id] = (byCategory[id] ?? 0) + cents;
    countByCategory[id] = (countByCategory[id] ?? 0) + 1;
  }

  for (final tx in snapshot.transactions) {
    final egp = tx.egpCents;
    if (tx.excluded || egp == null || !range.contains(tx.timestamp)) {
      continue;
    }
    switch (tx.kind) {
      case TxKind.purchase || TxKind.refund:
        final signed = tx.kind == TxKind.refund ? -egp : egp;
        final category = snapshot.effectiveCategory(tx);
        if (category == null) {
          uncategorized += signed;
          uncategorizedCount++;
        } else {
          addToCategory(category, signed);
        }
      case TxKind.cash || TxKind.transferOut:
        var left = egp;
        for (final split in snapshot.splitsOf(tx.id)) {
          addToCategory(split.categoryId, split.amountCents);
          left -= split.amountCents;
        }
        if (left > 0 && tx.kind == TxKind.cash) {
          cash += left;
          cashCount++;
        } else if (left > 0) {
          transfers += left;
          transferCount++;
        }
      case TxKind.transferIn:
        income += egp;
        incomeCount++;
    }
  }

  final categoryLines = [
    for (final category in snapshot.categories)
      if ((byCategory[category.id] ?? 0) != 0)
        SpendingLine(
          kind: LineKind.category,
          label: category.name,
          cents: byCategory[category.id]!,
          count: countByCategory[category.id]!,
          categoryId: category.id,
        ),
  ]..sort((a, b) => b.cents.compareTo(a.cents));

  final lines = [
    ...categoryLines,
    if (uncategorizedCount > 0)
      SpendingLine(
        kind: LineKind.uncategorized,
        label: 'No category yet',
        cents: uncategorized,
        count: uncategorizedCount,
      ),
    if (cashCount > 0)
      SpendingLine(
        kind: LineKind.unassignedCash,
        label: 'Cash withdrawal',
        cents: cash,
        count: cashCount,
      ),
    if (transferCount > 0)
      SpendingLine(
        kind: LineKind.unassignedTransfer,
        label: 'Transfers sent',
        cents: transfers,
        count: transferCount,
      ),
  ];

  return SpendingSummary(
    totalCents: lines.fold(0, (sum, line) => sum + line.cents),
    lines: lines,
    incomeCents: income,
    incomeCount: incomeCount,
  );
}

/// Transactions behind one line, newest first.
List<LedgerTransaction> transactionsFor(
  LedgerSnapshot snapshot,
  DayRange range,
  SpendingLine line,
) {
  bool matches(LedgerTransaction tx) => switch (line.kind) {
        LineKind.category => tx.kind.isAssignable
            ? snapshot
                .splitsOf(tx.id)
                .any((split) => split.categoryId == line.categoryId)
            : snapshot.effectiveCategory(tx) == line.categoryId &&
                tx.kind != TxKind.transferIn,
        LineKind.uncategorized =>
          (tx.kind == TxKind.purchase || tx.kind == TxKind.refund) &&
              snapshot.effectiveCategory(tx) == null,
        LineKind.unassignedCash => tx.kind == TxKind.cash &&
            snapshot.assignedCents(tx.id) < (tx.egpCents ?? 0),
        LineKind.unassignedTransfer => tx.kind == TxKind.transferOut &&
            snapshot.assignedCents(tx.id) < (tx.egpCents ?? 0),
        LineKind.moneyIn => tx.kind == TxKind.transferIn,
      };

  return snapshot.transactions
      .where((tx) =>
          !tx.excluded &&
          tx.egpCents != null &&
          range.contains(tx.timestamp) &&
          matches(tx))
      .toList();
}
