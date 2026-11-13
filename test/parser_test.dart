import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:masareef/parser/sms_parser.dart';

import 'support.dart';

void main() {
  final parser = SmsParser(loadPatterns());
  final samples = (jsonDecode(
    File('test/fixtures/sms_samples.json').readAsStringSync(),
  ) as List<Object?>)
      .cast<Map<String, Object?>>();

  group('every fixture parses as expected', () {
    for (final sample in samples) {
      test(sample['name']! as String, () {
        final expected = sample['expect']! as Map<String, Object?>;
        final actual = describe(parser.parse(sample['body']! as String));
        for (final MapEntry(:key, :value) in expected.entries) {
          expect(actual[key], value, reason: 'field "$key"');
        }
      });
    }
  });

  test('patterns file has a positive version', () {
    expect(loadPatterns().version, greaterThan(0));
  });

  test('bank senders are recognized case-insensitively', () {
    final patterns = loadPatterns();
    expect(patterns.isBankSender('QNB EGYPT'), isTrue);
    expect(patterns.isBankSender('FABMISR'), isTrue);
    expect(patterns.isBankSender('Mom'), isFalse);
  });
}

/// The parse result as the plain fields the fixtures describe.
Map<String, Object?> describe(ParseOutcome outcome) => switch (outcome) {
      final ParsedSms parsed => {
          'status': 'parsed',
          'kind': parsed.kind.dbName,
          'amountCents': parsed.amountCents,
          'currency': parsed.currency,
          'merchant': parsed.merchant,
          'card': parsed.card,
          'rule': parsed.ruleId,
        },
      final SkippedSms skipped => {'status': 'skipped', 'rule': skipped.ruleId},
      FailedSms() => {'status': 'failed'},
    };
