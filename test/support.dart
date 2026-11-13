import 'dart:convert';
import 'dart:io';

import 'package:masareef/data/sms_source.dart';
import 'package:masareef/domain/models.dart';
import 'package:masareef/parser/pattern_set.dart';

/// Reads patterns.json from disk so tests do not need Flutter assets.
PatternSet loadPatterns() => PatternSet.fromJson(
      jsonDecode(File('assets/parser/patterns.json').readAsStringSync())
          as Map<String, Object?>,
    );

/// An SMS inbox held in memory.
class FakeSmsSource implements SmsSource {
  FakeSmsSource(this.messages);

  final List<RawSms> messages;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<List<RawSms>> readInbox({required DateTime since}) async => messages
      .where((sms) => !sms.timestamp.isBefore(since))
      .toList();
}

LedgerTransaction tx({
  required int id,
  required TxKind kind,
  required int cents,
  required DateTime at,
  String merchantKey = '',
  int? categoryId,
  bool excluded = false,
  String currency = 'EGP',
}) =>
    LedgerTransaction(
      id: id,
      timestamp: at,
      kind: kind,
      amountCents: cents,
      currency: currency,
      egpCents: currency == 'EGP' ? cents : null,
      merchant: merchantKey.isEmpty ? null : merchantKey,
      merchantKey: merchantKey,
      categoryId: categoryId,
      source: 'TEST',
      excluded: excluded,
    );
