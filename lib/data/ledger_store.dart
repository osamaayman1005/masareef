import 'package:masareef/data/backup_store.dart';
import 'package:masareef/data/corrections_store.dart';
import 'package:masareef/data/rows.dart';
import 'package:masareef/domain/models.dart';
import 'package:sqflite/sqflite.dart';

/// All reads and writes of the ledger. The only class that knows SQL.
class LedgerStore {
  LedgerStore(this._db);

  final Database _db;

  // ---- Reads ----

  Future<LedgerSnapshot> load() async {
    final categories = await _db.query('categories', orderBy: 'sort_order, id');
    final rules = await _db.query('merchant_rules');
    final transactions =
        await _db.query('transactions', orderBy: 'timestamp DESC');
    final splits = await _db.query('splits', orderBy: 'id');
    final messages = await _db.query(
      'messages',
      where: 'status IN (?, ?, ?)',
      whereArgs: [
        MessageStatus.failed.dbName,
        MessageStatus.ignored.dbName,
        MessageStatus.dismissed.dbName,
      ],
      orderBy: 'timestamp DESC',
    );
    final ignoreRules = await _db.query('ignore_rules', orderBy: 'id DESC');
    final rates = await _db.query(
      'meta',
      where: 'key LIKE ?',
      whereArgs: ['$_ratePrefix%'],
    );
    return LedgerSnapshot(
      categories: categories.map(categoryFromRow).toList(),
      merchantRules: {
        for (final row in rules)
          row['merchant_key']! as String: row['category_id']! as int,
      },
      transactions: transactions.map(transactionFromRow).toList(),
      splits: splits.map(splitFromRow).toList(),
      messages: messages.map(messageFromRow).toList(),
      ignoreRules: ignoreRules.map(ignoreRuleFromRow).toList(),
      rates: {
        for (final row in rates)
          (row['key']! as String).substring(_ratePrefix.length):
              double.parse(row['value']! as String),
      },
    );
  }

  static const _ratePrefix = 'rate:';

  /// Keys of messages already stored at or after [since].
  Future<Set<String>> messageKeysSince(DateTime since) async {
    final rows = await _db.query(
      'messages',
      columns: ['key'],
      where: 'timestamp >= ?',
      whereArgs: [since.millisecondsSinceEpoch],
    );
    return {for (final row in rows) row['key']! as String};
  }

  /// Failed and ignored messages, for re-parsing after a parser update.
  Future<List<StoredMessage>> unreadMessages() async {
    final rows = await _db.query(
      'messages',
      where: 'status IN (?, ?)',
      whereArgs: [MessageStatus.failed.dbName, MessageStatus.ignored.dbName],
    );
    return rows.map(messageFromRow).toList();
  }

  /// Messages already read as money, to re-check after a parser update.
  Future<List<StoredMessage>> parsedMessages() async {
    final rows = await _db.query(
      'messages',
      where: 'status = ?',
      whereArgs: [MessageStatus.parsed.dbName],
    );
    return rows.map(messageFromRow).toList();
  }

  Future<String?> messageBody(String key) async {
    final rows = await _db.query(
      'messages',
      columns: ['body'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['body']! as String;
  }

  Future<String?> meta(String key) async {
    final rows = await _db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  /// Changes that override what the parser read: type and amount edits,
  /// and corrections after a parser update.
  CorrectionsStore get corrections => CorrectionsStore(_db);

  /// Export and restore of every table.
  BackupStore get backup => BackupStore(_db);

  // ---- Writes ----

  Future<void> setMeta(String key, String value) => _db.insert(
        'meta',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Stores [message] and, when given, its transaction in one step.
  /// A message already stored is left untouched, so nothing is counted twice.
  Future<void> saveMessage(StoredMessage message, [TransactionDraft? draft]) =>
      _db.transaction((txn) async {
        final existing = await txn.query(
          'messages',
          columns: ['key'],
          where: 'key = ?',
          whereArgs: [message.key],
        );
        if (existing.isNotEmpty) {
          return;
        }
        await txn.insert('messages', messageToRow(message));
        if (draft != null) {
          await txn.insert('transactions', draftToRow(draft));
        }
      });

  /// Marks an existing message and optionally attaches a new transaction.
  Future<void> updateMessage(
    String key,
    MessageStatus status, {
    String? rule,
    TransactionDraft? draft,
  }) =>
      _db.transaction((txn) async {
        await txn.update(
          'messages',
          {'status': status.dbName, 'rule': rule},
          where: 'key = ?',
          whereArgs: [key],
        );
        if (draft != null) {
          await txn.insert(
            'transactions',
            draftToRow(draft),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });

  Future<void> setMerchantRule(String merchantKey, int categoryId) =>
      _db.insert(
        'merchant_rules',
        {'merchant_key': merchantKey, 'category_id': categoryId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> setTransactionCategory(int id, int? categoryId) =>
      _updateTransaction(id, {'category_id': categoryId});

  /// Remembers EGP per one unit of [currency] for the next suggestion.
  Future<void> setRate(String currency, double egpPerUnit) =>
      setMeta('$_ratePrefix$currency', '$egpPerUnit');

  Future<void> setExcluded(int id, {required bool excluded}) =>
      _updateTransaction(id, {'excluded': excluded ? 1 : 0});

  /// A payment typed by hand, with no SMS behind it.
  Future<void> addManualPayment({
    required int cents,
    required int categoryId,
    required DateTime at,
  }) =>
      _db.insert(
        'transactions',
        draftToRow(
          TransactionDraft(
            timestamp: at,
            kind: TxKind.purchase,
            amountCents: cents,
            currency: 'EGP',
            merchant: null,
            merchantKey: '',
            source: manualSource,
            categoryId: categoryId,
          ),
        ),
      );

  static const String manualSource = 'Manual';

  Future<void> addSplit(int transactionId, int categoryId, int cents) =>
      _db.insert('splits', {
        'transaction_id': transactionId,
        'category_id': categoryId,
        'amount_cents': cents,
      });

  Future<void> deleteSplit(int id) =>
      _db.delete('splits', where: 'id = ?', whereArgs: [id]);

  Future<int> addIgnoreRule(String sender, String signature, String sample) =>
      _db.insert('ignore_rules', {
        'sender': sender,
        'signature': signature,
        'sample': sample,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

  /// Removes the rule and sends the messages it hid back to the Inbox.
  Future<void> deleteIgnoreRule(int id) => _db.transaction((txn) async {
        await txn.delete('ignore_rules', where: 'id = ?', whereArgs: [id]);
        await txn.update(
          'messages',
          {'status': MessageStatus.failed.dbName, 'rule': null},
          where: 'rule = ?',
          whereArgs: ['ignore:$id'],
        );
      });

  Future<void> addCategory(String name) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), 0) + 1 AS next FROM categories',
    );
    await _db.insert('categories', {
      'name': name,
      'sort_order': rows.first['next']! as int,
    });
  }

  Future<void> renameCategory(int id, String name) => _db.update(
        'categories',
        {'name': name},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<int> _updateTransaction(int id, Map<String, Object?> values) =>
      _db.update('transactions', values, where: 'id = ?', whereArgs: [id]);
}
