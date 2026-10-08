import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/services/supabase.dart';

/// A teacher's request to be paid what is ready.
class PayoutRequest {
  final int amountKobo;
  final DateTime? createdAt;

  /// `open`, `paid`, `cancelled` or `declined`.
  final String status;

  /// Why an admin declined it. Shown to the teacher.
  final String? resolutionNote;

  const PayoutRequest({
    required this.amountKobo,
    required this.createdAt,
    required this.status,
    this.resolutionNote,
  });

  factory PayoutRequest.fromJson(Map<String, dynamic> json,
          {String status = 'open'}) =>
      PayoutRequest(
        amountKobo: (json['amount_kobo'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
        status: (json['status'] ?? status).toString(),
        resolutionNote: json['resolution_note']?.toString(),
      );

  double get amount => amountKobo / 100;
  bool get declined => status == 'declined';
}

/// A transfer PadiLearn has sent to the teacher.
class PayoutRecord {
  final int amountKobo;
  final DateTime? paidAt;
  final String bankName;
  final String accountLast4;
  final String transferReference;

  const PayoutRecord({
    required this.amountKobo,
    required this.paidAt,
    required this.bankName,
    required this.accountLast4,
    required this.transferReference,
  });

  factory PayoutRecord.fromJson(Map<String, dynamic> json) => PayoutRecord(
        amountKobo: (json['amount_kobo'] as num?)?.toInt() ?? 0,
        paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? '')?.toLocal(),
        bankName: (json['bank_name'] ?? '').toString(),
        accountLast4: (json['account_last4'] ?? '').toString(),
        transferReference: (json['transfer_reference'] ?? '').toString(),
      );

  double get amount => amountKobo / 100;
}

/// What `my_payouts()` returns: the smallest request allowed, the open request
/// if there is one, the last closed one, and the transfers made.
class PayoutSummary {
  final int minimumKobo;
  final PayoutRequest? openRequest;
  final PayoutRequest? lastClosedRequest;
  final List<PayoutRecord> payouts;

  const PayoutSummary({
    required this.minimumKobo,
    required this.openRequest,
    required this.lastClosedRequest,
    required this.payouts,
  });

  factory PayoutSummary.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? object(String key) => json[key] is Map
        ? Map<String, dynamic>.from(json[key] as Map)
        : null;
    final open = object('open_request');
    final closed = object('last_closed_request');
    return PayoutSummary(
      minimumKobo: (json['minimum_kobo'] as num?)?.toInt() ?? 0,
      openRequest: open == null ? null : PayoutRequest.fromJson(open),
      lastClosedRequest: closed == null ? null : PayoutRequest.fromJson(closed),
      payouts: [
        for (final p in (json['payouts'] as List?) ?? const [])
          PayoutRecord.fromJson(Map<String, dynamic>.from(p as Map)),
      ],
    );
  }

  double get minimum => minimumKobo / 100;

  /// The last request was declined and nothing has been asked for since, so
  /// the teacher should see why.
  bool get showDecline =>
      openRequest == null && (lastClosedRequest?.declined ?? false);
}

/// Asking to be paid. Money still moves by hand: a request tells the admin
/// panel who is waiting, and recording the transfer there closes it. See
/// `supabase/migrations/20261008000001_payout_requests.sql`.
class PayoutService {
  static Future<PayoutSummary> summary() async {
    final result = await supabase.rpc('my_payouts');
    return PayoutSummary.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Asks for everything payable now. Returns the amount asked for, in kobo.
  static Future<int> request() async {
    try {
      final result = await supabase.rpc('request_payout');
      return (Map<String, dynamic>.from(result as Map)['amount_kobo'] as num)
          .toInt();
    } on PostgrestException catch (e) {
      // Two taps at once: the database's one-open-request index caught it.
      if (e.code == '23505') {
        throw Exception('You already have a payout request waiting');
      }
      throw Exception(e.message);
    }
  }

  static Future<void> cancel() async {
    try {
      await supabase.rpc('cancel_payout_request');
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}
