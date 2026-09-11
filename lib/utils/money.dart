/// Display formatting for money and counts.
///
/// These lived as copies: `'NGN ${x.toStringAsFixed(0)}'` was written out by
/// hand in six places, the "Free or price" label sat in the marketplace *card*
/// (which the marketplace screen then had to import a component to reach), and
/// the teacher earnings hint carried its own thousands-separator routine and
/// spelled the currency `₦` while every other screen spelled it `NGN`. One
/// place, one spelling.
library;

/// Digits with thousands separators, no decimals — naira amounts read better
/// whole. `4250.4` -> `"4,250"`.
String formatAmount(num value) {
  final whole = value.round().abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return buffer.toString();
}

/// A naira amount for display: `"NGN 4,250"`.
///
/// `NGN` rather than the `₦` glyph on purpose — it is present in every font we
/// ship, so it can never render as a tofu box on a device missing the symbol.
String formatNaira(num value) => 'NGN ${formatAmount(value)}';

/// Price label for a course: `"Free"` when it costs nothing.
String formatPriceLabel(num price) => price <= 0 ? 'Free' : formatNaira(price);

/// Compact count (e.g. 1200 -> "1.2k").
String formatStudentCount(num value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}
