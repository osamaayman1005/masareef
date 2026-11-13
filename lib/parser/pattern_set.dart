import 'package:masareef/domain/models.dart';

/// `patterns.json` compiled into regexes. See that file for the format.
class PatternSet {
  PatternSet._({
    required this.version,
    required this.bankSenders,
    required this.skipRules,
    required this.templates,
    required this.currency,
    required this.number,
    required this.money,
    required this.debitWords,
    required this.creditWords,
    required this.balanceBefore,
    required this.genericMerchant,
    required this.atmMerchant,
    required this.cardPatterns,
  });

  factory PatternSet.fromJson(Map<String, Object?> json) {
    final tokens = _map(json['tokens']).map(
      (key, value) => MapEntry(key, value! as String),
    );
    RegExp compile(Object? source) => RegExp(
          _expand(source! as String, tokens),
          caseSensitive: false,
          unicode: true,
        );
    final generic = _map(json['generic']);

    return PatternSet._(
      version: json['version']! as int,
      bankSenders: _list(json['bankSenders']).cast<String>(),
      skipRules: [
        for (final rule in _list(json['skip']).map(_map))
          NamedPattern(
              id: rule['id']! as String, regex: compile(rule['regex'])),
      ],
      templates: [
        for (final template in _list(json['templates']).map(_map))
          TemplatePattern(
            id: template['id']! as String,
            kind: TxKind.fromDbName(template['kind']! as String),
            regex: compile(template['regex']),
            fixedMerchant: template['merchant'] as String?,
          ),
      ],
      currency: compile('{CUR}'),
      number: compile('{NUM}'),
      money: compile('{MONEY}'),
      debitWords: compile(generic['debitWords']),
      creditWords: compile(generic['creditWords']),
      balanceBefore: compile(generic['balanceBefore']),
      genericMerchant: compile(generic['merchant']),
      atmMerchant: compile(json['atmMerchant']),
      cardPatterns: _list(json['card']).map(compile).toList(),
    );
  }

  /// Bumped whenever patterns change, so old failures are parsed again.
  final int version;
  final List<String> bankSenders;
  final List<NamedPattern> skipRules;
  final List<TemplatePattern> templates;
  final RegExp currency;
  final RegExp number;
  final RegExp money;
  final RegExp debitWords;
  final RegExp creditWords;
  final RegExp balanceBefore;
  final RegExp genericMerchant;
  final RegExp atmMerchant;
  final List<RegExp> cardPatterns;

  bool isBankSender(String sender) {
    final lower = sender.toLowerCase();
    return bankSenders.any(lower.contains);
  }

  static final _placeholder = RegExp(r'\{([A-Z]+)\}');

  static String _expand(String source, Map<String, String> tokens) {
    var expanded = source;
    for (var depth = 0;
        depth < 10 && _placeholder.hasMatch(expanded);
        depth++) {
      expanded = expanded.replaceAllMapped(
        _placeholder,
        (match) => tokens[match.group(1)] ?? match.group(0)!,
      );
    }
    return expanded;
  }

  static Map<String, Object?> _map(Object? value) =>
      value! as Map<String, Object?>;

  static List<Object?> _list(Object? value) => value! as List<Object?>;
}

class NamedPattern {
  const NamedPattern({required this.id, required this.regex});

  final String id;
  final RegExp regex;
}

class TemplatePattern {
  const TemplatePattern({
    required this.id,
    required this.kind,
    required this.regex,
    this.fixedMerchant,
  });

  final String id;
  final TxKind kind;
  final RegExp regex;

  /// Merchant to use when the template has no merchant group (e.g. `ATM`).
  final String? fixedMerchant;
}
