/// Text helpers used before matching and for message identity.
library;

import 'dart:convert';

final _whitespace = RegExp(r'\s+');
final _url = RegExp(r'https?://\S+|www\.\S+', caseSensitive: false);
final _numberRun = RegExp(r'\d+(?:[.,/:-]\d+)*');

/// Turns Arabic-Indic digits and separators into ASCII and collapses
/// whitespace, so one regex covers both scripts.
String normalizeSmsText(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    buffer.writeCharCode(switch (rune) {
      >= 0x0660 && <= 0x0669 => 0x30 + rune - 0x0660,
      >= 0x06F0 && <= 0x06F9 => 0x30 + rune - 0x06F0,
      0x066B => 0x2E,
      0x066C => 0x2C,
      0x200E || 0x200F || 0x00A0 => 0x20,
      _ => rune,
    });
  }
  return buffer.toString().replaceAll(_whitespace, ' ').trim();
}

/// The wording of a message with numbers, dates and links blanked out.
/// Two offers that differ only by date share a signature.
String messageSignature(String body) => normalizeSmsText(body)
    .toLowerCase()
    .replaceAll(_url, '<url>')
    .replaceAll(_numberRun, '#');

/// Word overlap between two signatures, from 0 (nothing shared) to 1.
double signatureSimilarity(String a, String b) {
  final left = a.split(' ').toSet();
  final right = b.split(' ').toSet();
  final union = left.union(right).length;
  if (union == 0) {
    return 0;
  }
  return left.intersection(right).length / union;
}

/// Stable identity for an SMS. The same message always gives the same key,
/// across syncs and app versions, so it is never counted twice.
String messageKey({
  required String sender,
  required DateTime timestamp,
  required String body,
}) {
  final bytes = utf8.encode('$sender|$body');
  return '${timestamp.millisecondsSinceEpoch}:'
      '${_fnv1a(bytes, 0x811c9dc5)}${_fnv1a(bytes, 0x050c5d1f)}';
}

String _fnv1a(List<int> bytes, int seed) {
  var hash = seed;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Lowercase letters and digits only. Used to remember merchants.
String merchantKeyOf(String? merchant) {
  if (merchant == null) {
    return '';
  }
  return merchant
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}

/// Display form: all-caps or all-lowercase names become Title Case.
String displayMerchant(String merchant) {
  final hasLetters = RegExp('[A-Za-z]').hasMatch(merchant);
  final mixed = merchant != merchant.toUpperCase() &&
      merchant != merchant.toLowerCase();
  if (!hasLetters || mixed) {
    return merchant;
  }
  return merchant
      .toLowerCase()
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
