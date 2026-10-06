/// Switches for behaviour that is built but not allowed to ship everywhere.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether paid courses can be bought inside the app.
///
/// This is a property of **how a build is distributed**, not of the platform
/// it runs on, so it is set at build time:
///
/// ```bash
/// # Web, and the APK handed out from padilearn.com — Paystack, 85% to the
/// # teacher, no store cut. PAID_CHECKOUT is redundant on web (it is the
/// # default there) but harmless.
/// flutter build web --release
/// flutter build apk --release --dart-define=PAID_CHECKOUT=true
///
/// # Anything uploaded to Google Play, including the closed test. Defaults
/// # to off on mobile — pass nothing.
/// flutter build appbundle --release
/// ```
///
/// **Never pass `PAID_CHECKOUT=true` to a build that goes to Play.** Play's
/// Payments policy requires digital content consumed in the app to be sold
/// through Play Billing, and separately forbids pointing users from inside
/// the app to an outside checkout — by button, link, WebView or message.
/// Apple's Guideline 3.1.1 says the same. The policy binds apps *distributed
/// through the store*, which is why the same code may take Paystack when the
/// APK is installed from our own site and must not when it arrives from Play.
/// A violation gets the app removed; a repeated one takes the developer
/// account with it.
///
/// While this is off the app must also not mention *where* a paid course
/// could be bought — including not linking to the website's catalogue.
/// Free courses are unaffected on every platform.
///
/// See "Start here" in `docs/LAUNCH_ANDROID.md` and `docs/LAUNCH_WEB.md`.
const bool kPaidCheckoutEnabled = bool.fromEnvironment(
  'PAID_CHECKOUT',
  defaultValue: kIsWeb,
);
