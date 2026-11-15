import 'package:sqflite/sqflite.dart';

/// Export and restore of every table, used by the copy/paste backup.
class BackupStore {
  BackupStore(this._db);

  final Database _db;

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
