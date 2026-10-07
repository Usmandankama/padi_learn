import 'package:padi_learn/utils/money.dart';

/// Money in the admin app is shown to the kobo, because the ledger is.
///
/// The student app rounds to whole naira (`formatNaira`), which is right for a
/// price tag and wrong for reconciling a refund against Paystack. Same `NGN`
/// spelling, for the same font-safety reason given in money.dart.
String formatKobo(num kobo) {
  final value = kobo.round();
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  final naira = formatAmount(abs ~/ 100);
  final rest = (abs % 100).toString().padLeft(2, '0');
  return '${sign}NGN $naira.$rest';
}

/// An amount typed in naira ("4,250", "4250.5", "NGN 4,250.00") as kobo. Null
/// unless it is a positive amount with at most two decimal places: a typo in
/// a payout should be refused, not rounded into a different number.
int? parseNairaToKobo(String input) {
  final cleaned =
      input.replaceAll(RegExp(r'ngn|₦|,|\s', caseSensitive: false), '');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final naira = int.parse(match.group(1)!);
  final kobo = int.parse((match.group(2) ?? '0').padRight(2, '0'));
  final total = naira * 100 + kobo;
  return total > 0 ? total : null;
}

/// Kobo as plain naira for an input field, without the NGN or separators that
/// [formatKobo] adds: `200000` -> `"2000.00"`.
String koboToPlainNaira(int kobo) =>
    '${kobo ~/ 100}.${(kobo % 100).toString().padLeft(2, '0')}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A timestamp from the database, in the admin's local time: `7 Oct 2026, 06:38`.
String formatWhen(Object? value) {
  final parsed = value is DateTime
      ? value
      : value is String
          ? DateTime.tryParse(value)
          : null;
  if (parsed == null) return '';
  final t = parsed.toLocal();
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${_months[t.month - 1]} ${t.year}, $hh:$mm';
}

/// A count from a JSON document, which may arrive as int, double or null.
int asCount(Object? value) => value is num ? value.toInt() : 0;
