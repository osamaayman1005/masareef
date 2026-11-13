/// Money helpers. All amounts in the app are integer cents to avoid rounding.
library;

/// Formats [cents] as `1,234.56`.
String formatCents(int cents) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final digits = (absolute ~/ 100).toString();
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  final whole = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    whole.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      whole.write(',');
    }
  }
  return '${negative ? '-' : ''}$whole.$fraction';
}

/// Parses typed input like `1,250.5` into cents. Returns null when invalid.
int? parseCents(String input) {
  final value = double.tryParse(input.replaceAll(',', '').trim());
  if (value == null || value.isNaN || value.isInfinite) {
    return null;
  }
  return (value * 100).round();
}
