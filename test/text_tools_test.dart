import 'package:flutter_test/flutter_test.dart';
import 'package:masareef/domain/money.dart';
import 'package:masareef/parser/text_tools.dart';

void main() {
  test('Arabic digits and separators become ASCII', () {
    expect(normalizeSmsText('٢٥٠٫٠٠  ج.م'), '250.00 ج.م');
  });

  test('the same SMS always has the same key', () {
    final at = DateTime(2026, 11, 12, 10, 8);
    final a = messageKey(sender: 'CIB', timestamp: at, body: 'hello');
    final b = messageKey(sender: 'CIB', timestamp: at, body: 'hello');
    final c = messageKey(sender: 'CIB', timestamp: at, body: 'hello!');
    expect(a, b);
    expect(a, isNot(c));
  });

  test('signatures ignore numbers and links', () {
    expect(
      messageSignature('Offer ends 10/11/2026 see https://x.eg/a'),
      messageSignature('Offer ends 12/12/2026 see https://x.eg/b'),
    );
  });

  test('merchant keys ignore case and punctuation', () {
    expect(
        merchantKeyOf('SEOUDI NEW ZAYED'), merchantKeyOf('Seoudi  new-zayed'));
    expect(merchantKeyOf(null), '');
  });

  test('money formatting and parsing round trip', () {
    expect(formatCents(5250000), '52,500.00');
    expect(formatCents(-999), '-9.99');
    expect(parseCents('1,250.5'), 125050);
    expect(parseCents('abc'), isNull);
  });
}
