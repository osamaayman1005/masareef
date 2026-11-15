import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:masareef/data/ledger_store.dart';
import 'package:masareef/domain/models.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/logic/inbox.dart';
import 'package:masareef/logic/spending.dart';
import 'package:masareef/logic/sync_service.dart';
import 'package:masareef/parser/text_tools.dart';

enum RangePreset { thisMonth, last7Days, all, custom }

/// The one place screens read state from and send actions to. Every action
/// writes through [LedgerStore] and then reloads, so the UI never holds data
/// the database does not.
class AppController extends ChangeNotifier {
  AppController({required this.store, required this.syncService});

  final LedgerStore store;
  final SyncService syncService;

  LedgerSnapshot _snapshot = LedgerSnapshot.empty;
  RangePreset _preset = RangePreset.thisMonth;
  DayRange _custom = DayRange(DateTime.now(), DateTime.now());
  bool _syncing = false;
  String _status = 'Not synced yet';

  LedgerSnapshot get snapshot => _snapshot;
  RangePreset get preset => _preset;
  bool get syncing => _syncing;
  String get status => _status;

  DayRange get range {
    final today = DateTime.now();
    return switch (_preset) {
      RangePreset.thisMonth =>
        DayRange(DateTime(today.year, today.month), today),
      RangePreset.last7Days =>
        DayRange(today.subtract(const Duration(days: 6)), today),
      RangePreset.all => DayRange(_earliest(), today),
      RangePreset.custom => _custom,
    };
  }

  SpendingSummary get summary => summarize(_snapshot, range);
  List<InboxItem> get inbox => buildInbox(_snapshot);

  Future<void> start() async {
    final recovered = await syncService.reparseIfParserChanged();
    await _reload();
    if (recovered > 0) {
      _setStatus('App update re-read $recovered old messages');
    }
  }

  void setPreset(RangePreset preset) {
    _preset = preset;
    notifyListeners();
  }

  void setCustomRange(DayRange range) {
    _custom = range;
    _preset = RangePreset.custom;
    notifyListeners();
  }

  /// Returns false when SMS permission was refused.
  Future<bool> sync({DateTime? since}) async {
    if (_syncing) {
      return true;
    }
    if (!await syncService.source.ensurePermission()) {
      _setStatus('SMS permission is needed to sync');
      return false;
    }
    _syncing = true;
    notifyListeners();
    try {
      final report = await syncService.sync(since: since);
      _status = 'Read ${report.read} messages · ${report.added} new payments'
          '${report.failed > 0 ? ' · ${report.failed} unread' : ''}';
    } on PlatformException catch (error) {
      _status = 'Sync failed: ${error.message ?? error.code}';
    } finally {
      _syncing = false;
    }
    await _reload();
    return true;
  }

  // ---- Categories ----

  Future<void> categorizeMerchant(String merchantKey, int categoryId) =>
      _write(() => store.setMerchantRule(merchantKey, categoryId));

  Future<void> categorizeTransaction(int id, int? categoryId) =>
      _write(() => store.setTransactionCategory(id, categoryId));

  Future<void> addCategory(String name) =>
      _write(() => store.addCategory(name));

  Future<void> renameCategory(int id, String name) =>
      _write(() => store.renameCategory(id, name));

  // ---- Cash and transfers ----

  /// Assigns [cents] of a cash withdrawal or sent transfer. Returns an error
  /// message, or null on success.
  Future<String?> assign(
      LedgerTransaction tx, int categoryId, int cents) async {
    final left = (tx.egpCents ?? 0) - _snapshot.assignedCents(tx.id);
    if (cents <= 0) {
      return 'Enter an amount above 0.';
    }
    if (cents > left) {
      return 'Only ${_money(left)} is left to assign.';
    }
    await _write(() => store.addSplit(tx.id, categoryId, cents));
    return null;
  }

  Future<void> removeSplit(int splitId) =>
      _write(() => store.deleteSplit(splitId));

  /// Saves an edited amount. For another currency the EGP amount is what the
  /// bank charged, and its rate is remembered for the next suggestion.
  Future<void> editAmount(
    int transactionId, {
    required String currency,
    required int amountCents,
    required int egpCents,
  }) =>
      _write(() async {
        await store.setAmount(
          transactionId,
          currency: currency,
          amountCents: amountCents,
          egpCents: egpCents,
        );
        if (currency != 'EGP' && amountCents > 0) {
          await store.setRate(currency, egpCents / amountCents);
        }
      });

  Future<void> setExcluded(int transactionId, {required bool excluded}) =>
      _write(() => store.setExcluded(transactionId, excluded: excluded));

  Future<void> changeKind(int transactionId, TxKind kind) =>
      _write(() => store.setKind(transactionId, kind));

  // ---- Unread messages ----

  Future<void> ignoreFormat(StoredMessage message) => _write(() async {
        final id = await store.addIgnoreRule(
          message.sender,
          messageSignature(message.body),
          message.body,
        );
        for (final other in _snapshot.messages) {
          final hidden = other.status == MessageStatus.failed &&
              matchingIgnoreRule(
                      [_rule(id, message)], other.sender, other.body) !=
                  null;
          if (hidden) {
            await store.updateMessage(
              other.key,
              MessageStatus.ignored,
              rule: 'ignore:$id',
            );
          }
        }
      });

  Future<void> stopIgnoring(int ruleId) =>
      _write(() => store.deleteIgnoreRule(ruleId));

  /// The user says this unread SMS was a payment and types its details.
  Future<void> enterManually(
    StoredMessage message, {
    required TxKind kind,
    required int cents,
    int? categoryId,
  }) =>
      _write(
        () => store.updateMessage(
          message.key,
          MessageStatus.manual,
          rule: 'manual',
          draft: TransactionDraft(
            messageKey: message.key,
            timestamp: message.timestamp,
            kind: kind,
            amountCents: cents,
            currency: 'EGP',
            merchant: message.sender,
            merchantKey: '',
            source: message.sender,
            categoryId: kind.isAssignable ? null : categoryId,
          ),
        ),
      );

  /// Not a payment, and no rule: only this one message is hidden.
  Future<void> dismiss(StoredMessage message) => _write(
        () => store.updateMessage(message.key, MessageStatus.dismissed),
      );

  /// Unread messages as JSON, to paste into a chat so the next app version
  /// can learn their format.
  String failuresReport() => const JsonEncoder.withIndent('  ').convert([
        for (final message in _snapshot.messages)
          if (message.status == MessageStatus.failed)
            {'sender': message.sender, 'body': message.body},
      ]);

  // ---- Backup ----

  Future<String> exportBackup() async => jsonEncode({
        'app': 'masareef',
        'format': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'tables': await store.exportTables(),
      });

  /// Throws [FormatException] when the text is not a Masareef backup.
  Future<void> importBackup(String text) async {
    final Object? decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?> || decoded['app'] != 'masareef') {
      throw const FormatException('This is not a Masareef backup.');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, Object?>) {
      throw const FormatException('The backup has no data.');
    }
    final rows = <String, List<Map<String, Object?>>>{};
    for (final MapEntry(:key, :value) in tables.entries) {
      if (value is! List<Object?>) {
        throw const FormatException('The backup is damaged.');
      }
      rows[key] = [
        for (final row in value)
          if (row is Map<String, Object?>)
            row
          else
            throw const FormatException('The backup is damaged.'),
      ];
    }
    await _write(() => store.importTables(rows));
  }

  // ---- Internals ----

  Future<void> _write(Future<void> Function() action) async {
    await action();
    await _reload();
  }

  Future<void> _reload() async {
    _snapshot = await store.load();
    notifyListeners();
  }

  void _setStatus(String value) {
    _status = value;
    notifyListeners();
  }

  DateTime _earliest() => _snapshot.transactions.isEmpty
      ? DateTime.now()
      : _snapshot.transactions.last.timestamp;

  static String _money(int cents) => 'EGP ${formatCents(cents)}';

  static IgnoreRule _rule(int id, StoredMessage message) => IgnoreRule(
        id: id,
        sender: message.sender,
        signature: messageSignature(message.body),
        sample: message.body,
        createdAt: DateTime.now(),
      );
}
