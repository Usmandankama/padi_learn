/// Switches for behaviour that is built but not allowed to ship yet.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Whether paid courses can be bought inside the app.
///
/// On the **web** this is on. The restriction below is a store rule, and the
/// web is not a store: selling a course at padilearn.com involves no Play
/// Billing, no 15–30% cut, and no review. Paystack is charged directly and the
/// teacher's 85% is unaffected.
///
/// On **Android and iOS** it stays off, because an in-app Paystack checkout
/// breaks Google Play's Payments policy (and Apple's Guideline 3.1.1): digital
/// content consumed in the app has to be sold through the store's own billing.
/// The policy also forbids pointing users from the app to an outside checkout,
/// so while this is off the app must not mention *where* a paid course could
/// be bought — including not linking to the website's catalogue.
///
/// Turn the mobile side on only once the payment path is decided — see
/// "Start here" in `docs/LAUNCH_ANDROID.md`. Free courses are unaffected
/// on every platform.
const bool kPaidCheckoutEnabled = kIsWeb;
