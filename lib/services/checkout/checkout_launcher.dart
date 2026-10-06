import 'package:flutter/widgets.dart';

import 'checkout_launcher_io.dart'
    if (dart.library.js_interop) 'checkout_launcher_web.dart' as impl;

/// How handing the user to Paystack ended.
///
/// Mobile and web differ in kind, not just in detail. On mobile the checkout
/// is a screen this app pushes and pops, so the purchase finishes inside the
/// same `await`. On web the browser navigates away to Paystack and this app
/// instance is destroyed — the result comes back as a fresh page load on the
/// callback route, and nothing after the launch call runs.
enum CheckoutOutcome {
  /// Paystack reached the callback URL while still inside the app. The server
  /// can be asked to verify immediately.
  returned,

  /// The user backed out without completing payment.
  abandoned,

  /// The browser is leaving this page. Verification happens on the callback
  /// route; the caller must stop and do nothing further.
  redirected,
}

/// Sends the user to Paystack's checkout for [authorizationUrl].
///
/// [courseId] and [reference] are recorded before a web redirect so the
/// callback route can finish the purchase after the app has been reloaded.
Future<CheckoutOutcome> launchCheckout(
  BuildContext context, {
  required String courseId,
  required String courseTitle,
  required String authorizationUrl,
  required String callbackUrl,
  required String reference,
}) =>
    impl.launchCheckout(
      context,
      courseId: courseId,
      courseTitle: courseTitle,
      authorizationUrl: authorizationUrl,
      callbackUrl: callbackUrl,
      reference: reference,
    );
