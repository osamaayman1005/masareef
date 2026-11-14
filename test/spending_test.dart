import 'package:flutter_test/flutter_test.dart';
import 'package:masareef/domain/models.dart';
import 'package:masareef/logic/inbox.dart';
import 'package:masareef/logic/spending.dart';

import 'support.dart';

void main() {
  final day = DateTime(2026, 11, 10, 12);
  final november = DayRange(DateTime(2026, 11), DateTime(2026, 11, 30));
  const groceries = ExpenseCategory(id: 1, name: 'Groceries', sortOrder: 0);
  const installments =
      ExpenseCategory(id: 2, name: 'Installments', sortOrder: 1);

  LedgerSnapshot snapshot({
    List<LedgerTransaction> transactions = const [],
    List<Split> splits = const [],
    Map<String, int> rules = const {},
  }) =>
      LedgerSnapshot(
        categories: const [groceries, installments],
        merchantRules: rules,
        transactions: transactions,
        splits: splits,
        messages: const [],
        ignoreRules: const [],
      );

  test('a remembered merchant puts payments in its category', () {
    final summary = summarize(
      snapshot(
        transactions: [
          tx(
              id: 1,
              kind: TxKind.purchase,
              cents: 2000,
              at: day,
              merchantKey: 'seoudi'),
          tx(
              id: 2,
              kind: TxKind.purchase,
              cents: 500,
              at: day,
              merchantKey: 'seoudi'),
        ],
        rules: {'seoudi': 1},
      ),
      november,
    );
    expect(summary.totalCents, 2500);
    expect(summary.lines.single.label, 'Groceries');
    expect(summary.lines.single.count, 2);
  });

  test('refunds subtract from their category', () {
    final summary = summarize(
      snapshot(
        transactions: [
          tx(
              id: 1,
              kind: TxKind.purchase,
              cents: 1000,
              at: day,
              merchantKey: 'a'),
          tx(id: 2, kind: TxKind.refund, cents: 400, at: day, merchantKey: 'a'),
        ],
        rules: {'a': 1},
      ),
      november,
    );
    expect(summary.totalCents, 600);
  });

  test('cash counts as cash withdrawal until it is split', () {
    final cash = tx(id: 1, kind: TxKind.cash, cents: 100000, at: day);
    final before = summarize(snapshot(transactions: [cash]), november);
    expect(before.lines.single.kind, LineKind.unassignedCash);
    expect(before.totalCents, 100000);

    final after = summarize(
      snapshot(
        transactions: [cash],
        splits: const [
          Split(id: 1, transactionId: 1, categoryId: 1, amountCents: 50000)
        ],
      ),
      november,
    );
    expect(after.totalCents, 100000,
        reason: 'splitting never changes the total');
    expect(after.lines.map((line) => line.cents), [50000, 50000]);
  });

  test('a whole sent transfer can go to one category', () {
    final transfer =
        tx(id: 1, kind: TxKind.transferOut, cents: 5250000, at: day);
    final summary = summarize(
      snapshot(
        transactions: [transfer],
        splits: const [
          Split(id: 1, transactionId: 1, categoryId: 2, amountCents: 5250000),
        ],
      ),
      november,
    );
    expect(summary.lines.single.label, 'Installments');
    expect(summary.lines.single.cents, 5250000);
  });

  test('money in, excluded and out-of-range entries are not spending', () {
    final summary = summarize(
      snapshot(
        transactions: [
          tx(id: 1, kind: TxKind.transferIn, cents: 2670000, at: day),
          tx(id: 2, kind: TxKind.purchase, cents: 900, at: day, excluded: true),
          tx(
              id: 3,
              kind: TxKind.purchase,
              cents: 700,
              at: DateTime(2026, 10, 5)),
        ],
      ),
      november,
    );
    expect(summary.totalCents, 0);
    expect(summary.incomeCents, 2670000);
    expect(summary.incomeCount, 1);
    expect(summary.incomeLine.kind, LineKind.moneyIn);
  });

  test('foreign charges wait in the Inbox and stay out of totals', () {
    final usd =
        tx(id: 1, kind: TxKind.purchase, cents: 999, at: day, currency: 'USD');
    final data = snapshot(transactions: [usd]);
    expect(summarize(data, november).totalCents, 0);
    expect(buildInbox(data).whereType<ForeignCharge>(), hasLength(1));
  });

  test('the Inbox asks once per merchant', () {
    final inbox = buildInbox(
      snapshot(
        transactions: [
          tx(
              id: 1,
              kind: TxKind.purchase,
              cents: 5079,
              at: day,
              merchantKey: 'sahl'),
          tx(
              id: 2,
              kind: TxKind.purchase,
              cents: 100,
              at: day,
              merchantKey: 'sahl'),
        ],
      ),
    );
    final question = inbox.single as MerchantQuestion;
    expect(question.count, 2);
    expect(question.totalCents, 5179);
  });
}
