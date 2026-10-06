import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:padi_learn/services/pending_purchase.dart';

import 'checkout_launcher.dart' show CheckoutOutcome;

/// Web: there is no WebView, and there does not need to be — the browser is
/// one. We navigate the current tab to Paystack (`_self`, so the back button
/// still works and popup blockers never see it) and let Paystack redirect to
/// the callback URL when it is done.
///
/// That redirect reloads the app from scratch, so the reference is written to
/// local storage first. Without it the callback route would know a payment had
/// happened but not which course it was for.
Future<CheckoutOutcome> launchCheckout(
  BuildContext context, {
  required String courseId,
  required String courseTitle,
  required String authorizationUrl,
  required String callbackUrl,
  required String reference,
}) async {
  await PendingPurchase.save(
    reference: reference,
    courseId: courseId,
    courseTitle: courseTitle,
  );

  await launchUrl(
    Uri.parse(authorizationUrl),
    webOnlyWindowName: '_self',
  );

  // The page is unloading. Anything after this in the caller must not run.
  return CheckoutOutcome.redirected;
}
