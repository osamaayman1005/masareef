import 'package:masareef/data/ledger_store.dart';
import 'package:masareef/data/sms_source.dart';
import 'package:masareef/domain/models.dart';
import 'package:masareef/parser/sms_parser.dart';
import 'package:masareef/parser/text_tools.dart';

class SyncReport {
  const SyncReport({required this.read, required this.added, required this.failed});

  final int read;
  final int added;
  final int failed;
}

/// Moves SMS from the phone into the ledger. Safe to run any number of
/// times: every SMS has a stable key and is stored at most once.
class SyncService {
  SyncService({required this.store, required this.source, required this.parser});

  final LedgerStore store;
  final SmsSource source;
  final SmsParser parser;

  static const _lastSyncKey = 'last_sync_ms';
  static const _parserVersionKey = 'parser_version';

  /// How far back the very first sync reads.
  static const Duration firstSyncWindow = Duration(days: 180);

  /// Re-read a little before the last sync in case the phone delivered an
  /// SMS late. Duplicates are dropped by key.
  static const Duration overlap = Duration(days: 2);

  Future<SyncReport> sync({DateTime? since}) async {
    final now = DateTime.now();
    final last = await store.meta(_lastSyncKey);
    final from = since ??
        (last == null
            ? now.subtract(firstSyncWindow)
            : DateTime.fromMillisecondsSinceEpoch(int.parse(last))
                .subtract(overlap));

    final inbox = await source.readInbox(since: from);
    final known = await store.messageKeysSince(from);
    final ignoreRules = (await store.load()).ignoreRules;
    var added = 0;
    var failed = 0;

    for (final sms in inbox) {
      final key = messageKey(
        sender: sms.sender,
        timestamp: sms.timestamp,
        body: sms.body,
      );
      if (!known.add(key)) {
        continue;
      }
      final outcome = parser.parse(sms.body);
      final isBank = parser.patterns.isBankSender(sms.sender);
      switch (outcome) {
        case final ParsedSms parsed when isBank || parsed.ruleId != 'generic':
          await store.saveMessage(
            _message(key, sms, MessageStatus.parsed, parsed.ruleId),
            draftFrom(parsed, key, sms.sender, sms.timestamp),
          );
          added++;
        case final SkippedSms skipped when isBank:
          await store.saveMessage(
            _message(key, sms, MessageStatus.skipped, skipped.ruleId),
          );
        case _ when isBank:
          final rule = matchingIgnoreRule(ignoreRules, sms.sender, sms.body);
          final status =
              rule == null ? MessageStatus.failed : MessageStatus.ignored;
          await store.saveMessage(
            _message(key, sms, status, rule == null ? null : 'ignore:${rule.id}'),
          );
          if (rule == null) {
            failed++;
          }
        case _:
          // Personal SMS and OTPs from other senders are not stored at all.
          break;
      }
    }

    await store.setMeta(_lastSyncKey, '${now.millisecondsSinceEpoch}');
    return SyncReport(read: inbox.length, added: added, failed: failed);
  }

  /// After an app update with new patterns, tries old failures again.
  Future<int> reparseIfParserChanged() async {
    final stored = await store.meta(_parserVersionKey);
    if (stored == '${parser.patterns.version}') {
      return 0;
    }
    var recovered = 0;
    for (final message in await store.unreadMessages()) {
      final outcome = parser.parse(message.body);
      if (outcome is ParsedSms) {
        await store.updateMessage(
          message.key,
          MessageStatus.parsed,
          rule: outcome.ruleId,
          draft: draftFrom(outcome, message.key, message.sender, message.timestamp),
        );
        recovered++;
      }
    }
    await store.setMeta(_parserVersionKey, '${parser.patterns.version}');
    return recovered;
  }

  static StoredMessage _message(
    String key,
    RawSms sms,
    MessageStatus status,
    String? rule,
  ) =>
      StoredMessage(
        key: key,
        sender: sms.sender,
        body: sms.body,
        timestamp: sms.timestamp,
        status: status,
        rule: rule,
      );
}

/// Turns a parse result into a transaction to store.
TransactionDraft draftFrom(
  ParsedSms parsed,
  String key,
  String sender,
  DateTime timestamp,
) =>
    TransactionDraft(
      messageKey: key,
      timestamp: timestamp,
      kind: parsed.kind,
      amountCents: parsed.amountCents,
      currency: parsed.currency,
      merchant: parsed.merchant,
      merchantKey: parsed.kind.isAssignable ? '' : merchantKeyOf(parsed.merchant),
      source: sender,
      card: parsed.card,
    );

/// Ignore rules only ever apply to messages the parser could not read, so
/// a real payment can never be hidden by one.
IgnoreRule? matchingIgnoreRule(
  List<IgnoreRule> rules,
  String sender,
  String body,
) {
  final signature = messageSignature(body);
  for (final rule in rules) {
    final sameSender = rule.sender.toLowerCase() == sender.toLowerCase();
    if (sameSender && signatureSimilarity(rule.signature, signature) >= 0.6) {
      return rule;
    }
  }
  return null;
}
