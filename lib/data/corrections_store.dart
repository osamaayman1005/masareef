import 'package:masareef/data/rows.dart';
import 'package:masareef/domain/models.dart';
import 'package:sqflite/sqflite.dart';

/// Writes that override what the parser read. Anything the user corrects by
/// hand is marked, so a later parser update never undoes it.
class CorrectionsStore {
  CorrectionsStore(this._db);

  final Database _db;

  /// Corrects what a transaction is, e.g. a debit that was really money in.
  /// Splits are removed when the new type cannot be split.
  Future<void> setKind(int id, TxKind kind) => _db.transaction((txn) async {
        await txn.update(
          'transactions',
          {'kind': kind.dbName, 'kind_set_by_user': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        if (!kind.isAssignable) {
          await txn.delete(
            'splits',
            where: 'transaction_id = ?',
            whereArgs: [id],
          );
        }
      });

  /// Sets what a transaction cost, in [currency] and in EGP. Marked as set
  /// by hand so parser updates keep it. Splits are removed when they would
  /// add up to more than the new amount.
  Future<void> setAmount(
    int id, {
    required String currency,
    required int amountCents,
    required int egpCents,
  }) =>
      _db.transaction((txn) async {
        await txn.update(
          'transactions',
          {
            'currency': currency,
            'amount_cents': amountCents,
            'egp_cents': egpCents,
            'amount_set_by_user': 1,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        final rows = await txn.rawQuery(
          'SELECT COALESCE(SUM(amount_cents), 0) AS total '
          'FROM splits WHERE transaction_id = ?',
          [id],
        );
        if ((rows.first['total']! as int) > egpCents) {
          await txn.delete(
            'splits',
            where: 'transaction_id = ?',
            whereArgs: [id],
          );
        }
      });

  /// Rewrites a transaction that an updated parser reads differently, for
  /// example a salary that was first read as money sent. Its category and
  /// exclusion stay. Splits are removed when they no longer fit. Returns
  /// true when something changed.
  Future<bool> correctTransaction(TransactionDraft draft) =>
      _db.transaction((txn) async {
        final rows = await txn.query(
          'transactions',
          where: 'message_key = ?',
          whereArgs: [draft.messageKey],
        );
        if (rows.isEmpty) {
          return false;
        }
        final current = transactionFromRow(rows.first);
        if (current.kindSetByUser || current.amountSetByUser) {
          return false;
        }
        final unchanged = current.kind == draft.kind &&
            current.amountCents == draft.amountCents &&
            current.currency == draft.currency;
        if (unchanged) {
          return false;
        }
        await txn.update(
          'transactions',
          {
            'kind': draft.kind.dbName,
            'amount_cents': draft.amountCents,
            'currency': draft.currency,
            'egp_cents': draft.currency == 'EGP' ? draft.amountCents : null,
            'merchant': draft.merchant,
            'merchant_key': draft.merchantKey,
            'card': draft.card,
          },
          where: 'id = ?',
          whereArgs: [current.id],
        );
        final splitsStillFit =
            draft.kind.isAssignable && draft.amountCents == current.amountCents;
        if (!splitsStillFit) {
          await txn.delete(
            'splits',
            where: 'transaction_id = ?',
            whereArgs: [current.id],
          );
        }
        return true;
      });
}
