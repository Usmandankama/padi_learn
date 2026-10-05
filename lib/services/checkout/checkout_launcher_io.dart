import 'package:flutter/material.dart';
import 'package:padi_learn/screens/payment/paystack_checkout_screen.dart';

import 'checkout_launcher.dart' show CheckoutOutcome;

/// Mobile and desktop: Paystack runs in a WebView this app owns, so the
/// purchase begins and ends inside one `await`. Nothing is persisted —
/// the app is never torn down mid-checkout.
Future<CheckoutOutcome> launchCheckout(
  BuildContext context, {
  required String courseId,
  required String courseTitle,
  required String authorizationUrl,
  required String callbackUrl,
  required String reference,
}) async {
  final completed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => PaystackCheckoutScreen(
        authorizationUrl: authorizationUrl,
        callbackUrl: callbackUrl,
      ),
    ),
  );
  return completed == true ? CheckoutOutcome.returned : CheckoutOutcome.abandoned;
}
