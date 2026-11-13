import 'package:masareef/domain/models.dart';
import 'package:masareef/parser/pattern_set.dart';
import 'package:masareef/parser/text_tools.dart';

sealed class ParseOutcome {
  const ParseOutcome();
}

/// A money movement read from the SMS.
final class ParsedSms extends ParseOutcome {
  const ParsedSms({
    required this.kind,
    required this.amountCents,
    required this.currency,
    required this.ruleId,
    this.merchant,
    this.card,
  });

  final TxKind kind;
  final int amountCents;
  final String currency;
  final String? merchant;
  final String? card;
  final String ruleId;
}

/// Known not to be a money movement (OTP, declined payment).
final class SkippedSms extends ParseOutcome {
  const SkippedSms(this.ruleId);

  final String ruleId;
}

/// Could not be read. Goes to the Inbox and the failure log.
final class FailedSms extends ParseOutcome {
  const FailedSms();
}

/// Reads bank SMS with three layers: skip rules, bank templates, then a
/// generic amount-and-keyword fallback. All patterns live in patterns.json.
class SmsParser {
  const SmsParser(this.patterns);

  final PatternSet patterns;

  ParseOutcome parse(String body) {
    final text = normalizeSmsText(body);
    for (final rule in patterns.skipRules) {
      if (rule.regex.hasMatch(text)) {
        return SkippedSms(rule.id);
      }
    }
    return _fromTemplates(text) ?? _fromGeneric(text) ?? const FailedSms();
  }

  ParsedSms? _fromTemplates(String text) {
    for (final template in patterns.templates) {
      final match = template.regex.firstMatch(text);
      if (match == null) {
        continue;
      }
      final money = _readMoney(_group(match, 'money'));
      if (money == null) {
        continue;
      }
      final merchant =
          _cleanMerchant(_group(match, 'merchant')) ?? template.fixedMerchant;
      return _build(template.kind, money, merchant, template.id, text);
    }
    return null;
  }

  ParsedSms? _fromGeneric(String text) {
    final isDebit = patterns.debitWords.hasMatch(text);
    final isCredit = !isDebit && patterns.creditWords.hasMatch(text);
    if (!isDebit && !isCredit) {
      return null;
    }
    for (final match in patterns.money.allMatches(text)) {
      if (patterns.balanceBefore.hasMatch(text.substring(0, match.start))) {
        continue;
      }
      final money = _readMoney(_group(match, 'money'));
      if (money == null) {
        continue;
      }
      final merchantMatch = patterns.genericMerchant.firstMatch(text);
      final merchant = merchantMatch == null
          ? null
          : _cleanMerchant(_group(merchantMatch, 'merchant'));
      final kind = isDebit ? TxKind.purchase : TxKind.transferIn;
      return _build(kind, money, merchant, 'generic', text);
    }
    return null;
  }

  ParsedSms _build(
    TxKind kind,
    ({int cents, String currency}) money,
    String? merchant,
    String ruleId,
    String text,
  ) {
    final atAtm = merchant != null && patterns.atmMerchant.hasMatch(merchant);
    final isCash = kind == TxKind.purchase && atAtm;
    return ParsedSms(
      kind: isCash ? TxKind.cash : kind,
      amountCents: money.cents,
      currency: money.currency,
      merchant: isCash ? 'ATM' : merchant,
      card: _findCard(text),
      ruleId: ruleId,
    );
  }

  ({int cents, String currency})? _readMoney(String? token) {
    if (token == null) {
      return null;
    }
    final currency = patterns.currency.firstMatch(token)?.group(0);
    final number = patterns.number.firstMatch(token)?.group(0);
    if (currency == null || number == null) {
      return null;
    }
    final value = double.tryParse(number.replaceAll(',', ''));
    if (value == null || value <= 0) {
      return null;
    }
    return (cents: (value * 100).round(), currency: _currencyCode(currency));
  }

  String? _findCard(String text) {
    for (final pattern in patterns.cardPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return _group(match, 'card');
      }
    }
    return null;
  }

  static final _leadingJunk = RegExp(r'^[@\s:#-]+');
  static final _trailingJunk = RegExp(r'[\s.,،:;-]+$');

  static String? _cleanMerchant(String? raw) {
    if (raw == null) {
      return null;
    }
    final cleaned =
        raw.replaceAll(_leadingJunk, '').replaceAll(_trailingJunk, '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// RegExpMatch.namedGroup throws for names the regex does not define.
  static String? _group(RegExpMatch match, String name) =>
      match.groupNames.contains(name) ? match.namedGroup(name) : null;

  static const _currencyCodes = <(String, String)>[
    ('usd', 'USD'),
    ('us\$', 'USD'),
    (r'$', 'USD'),
    ('دولار', 'USD'),
    ('eur', 'EUR'),
    ('€', 'EUR'),
    ('يورو', 'EUR'),
    ('gbp', 'GBP'),
    ('£', 'GBP'),
    ('sar', 'SAR'),
    ('ريال', 'SAR'),
    ('aed', 'AED'),
    ('درهم', 'AED'),
    ('kwd', 'KWD'),
    ('qar', 'QAR'),
  ];

  static String _currencyCode(String token) {
    final lower = token.toLowerCase();
    for (final (prefix, code) in _currencyCodes) {
      if (lower.startsWith(prefix)) {
        return code;
      }
    }
    return 'EGP';
  }
}
