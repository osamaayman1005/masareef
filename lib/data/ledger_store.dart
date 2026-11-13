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
    );
  }

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

  Future<void> setEgpAmount(int id, int egpCents) =>
      _updateTransaction(id, {'egp_cents': egpCents});

  Future<void> setExcluded(int id, {required bool excluded}) =>
      _updateTransaction(id, {'excluded': excluded ? 1 : 0});

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

  // ---- Backup ----

  static const List<String> backupTables = [
    'categories',
    'messages',
    'transactions',
    'splits',
    'merchant_rules',
    'ignore_rules',
    'meta',
  ];

  Future<Map<String, List<Map<String, Object?>>>> exportTables() async => {
        for (final table in backupTables) table: await _db.query(table),
      };

  /// Replaces everything with [tables]. Runs in one transaction, so a bad
  /// backup leaves the current data as it was.
  Future<void> importTables(Map<String, List<Map<String, Object?>>> tables) =>
      _db.transaction((txn) async {
        for (final table in backupTables.reversed) {
          await txn.delete(table);
        }
        for (final table in backupTables) {
          for (final row in tables[table] ?? const <Map<String, Object?>>[]) {
            await txn.insert(table, row);
          }
        }
      });
}
