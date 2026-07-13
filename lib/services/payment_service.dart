import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:padi_learn/services/supabase.dart';

/// Result of initializing a Paystack transaction.
class PaymentInit {
  final String authorizationUrl;
  final String reference;
  const PaymentInit(this.authorizationUrl, this.reference);
}

/// Talks to the Supabase Edge Functions that own the Paystack secret key.
/// The app never sees the secret key, the price, or performs verification
/// itself — initialization and verification are server-authoritative.
class PaymentService {
  /// URL Paystack redirects to after checkout. It never needs to resolve — the
  /// checkout WebView just intercepts navigation to it.
  static const String callbackUrl = 'https://padilearn.app/payment-callback';

  /// Starts a transaction for [courseId] and returns the checkout URL + ref.
  static Future<PaymentInit> initialize(String courseId) async {
    try {
      final res = await supabase.functions.invoke(
        'initialize-payment',
        body: {'courseId': courseId, 'callbackUrl': callbackUrl},
      );
      final data = res.data as Map?;
      final url = data?['authorization_url'] as String?;
      final ref = data?['reference'] as String?;
      if (url == null || ref == null) {
        throw Exception(data?['error'] ?? 'Could not start payment.');
      }
      return PaymentInit(url, ref);
    } on FunctionException catch (e) {
      throw Exception(_message(e.details) ?? 'Could not start payment.');
    }
  }

  /// Asks the server to verify [reference] with Paystack and (on success)
  /// create the enrollment. Returns whether the payment was confirmed.
  static Future<bool> verify(String reference) async {
    try {
      final res = await supabase.functions.invoke(
        'verify-payment',
        body: {'reference': reference},
      );
      final data = res.data as Map?;
      return data?['success'] == true;
    } on FunctionException {
      return false;
    }
  }

  static String? _message(dynamic details) {
    if (details is Map) {
      return (details['error'] ?? details['message'])?.toString();
    }
    return null;
  }
}
