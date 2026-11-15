import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const _addKindSetByUser = 'ALTER TABLE transactions '
    'ADD COLUMN kind_set_by_user INTEGER NOT NULL DEFAULT 0';

const _addAmountSetByUser = 'ALTER TABLE transactions '
    'ADD COLUMN amount_set_by_user INTEGER NOT NULL DEFAULT 0';

/// Schema history. Append a new step for every change; never edit or remove
/// an old one, or existing installs will lose data on update.
const _migrations = <List<String>>[
  // v1
  [
    '''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      sort_order INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE messages (
      key TEXT PRIMARY KEY,
      sender TEXT NOT NULL,
      body TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      status TEXT NOT NULL,
      rule TEXT
    )''',
    '''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message_key TEXT UNIQUE REFERENCES messages(key),
      timestamp INTEGER NOT NULL,
      kind TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      currency TEXT NOT NULL,
      egp_cents INTEGER,
      merchant TEXT,
      merchant_key TEXT NOT NULL,
      category_id INTEGER REFERENCES categories(id),
      source TEXT NOT NULL,
      card TEXT,
      excluded INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE splits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_id INTEGER NOT NULL
        REFERENCES transactions(id) ON DELETE CASCADE,
      category_id INTEGER NOT NULL REFERENCES categories(id),
      amount_cents INTEGER NOT NULL
    )''',
    '''
    CREATE TABLE merchant_rules (
      merchant_key TEXT PRIMARY KEY,
      category_id INTEGER NOT NULL REFERENCES categories(id)
    )''',
    '''
    CREATE TABLE ignore_rules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sender TEXT NOT NULL,
      signature TEXT NOT NULL,
      sample TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )''',
    'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    'CREATE INDEX idx_transactions_time ON transactions(timestamp)',
    'CREATE INDEX idx_messages_time ON messages(timestamp)',
  ],
  // v2: the user can correct a transaction's type; parser updates keep it.
  [
    _addKindSetByUser,
  ],
  // v3: the user can edit an amount and its currency; parser updates keep it.
  [
    _addAmountSetByUser,
  ],
];

const List<String> starterCategories = [
  'Groceries',
  'Eating out',
  'Bills & utilities',
  'Subscriptions',
  'Transport',
  'Shopping',
  'Health',
  'Rent & home',
  'Installments',
  'Family & gifts',
  'Other',
];

/// Opens (and creates or upgrades) the app database. Tests pass their own
/// [factory] and an in-memory [path].
Future<Database> openAppDatabase(
    {String? path, DatabaseFactory? factory}) async {
  final dbFactory = factory ?? databaseFactory;
  final file =
      path ?? p.join(await dbFactory.getDatabasesPath(), 'masareef.db');
  return dbFactory.openDatabase(
    file,
    options: OpenDatabaseOptions(
      version: _migrations.length,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _migrate(db, from: 0, to: version),
      onUpgrade: (db, from, to) => _migrate(db, from: from, to: to),
    ),
  );
}

Future<void> _migrate(Database db, {required int from, required int to}) async {
  final batch = db.batch();
  for (var version = from + 1; version <= to; version++) {
    _migrations[version - 1].forEach(batch.execute);
    if (version == 1) {
      for (final (index, name) in starterCategories.indexed) {
        batch.insert('categories', {'name': name, 'sort_order': index});
      }
    }
  }
  await batch.commit(noResult: true);
}
