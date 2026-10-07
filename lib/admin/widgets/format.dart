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
