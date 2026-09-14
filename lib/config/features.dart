/// Switches for behaviour that is built but not allowed to ship yet.
library;

/// Whether paid courses can be bought inside the app.
///
/// Off, because the in-app Paystack checkout breaks Google Play's Payments
/// policy (and Apple's Guideline 3.1.1): digital content consumed in the app
/// has to be sold through the store's own billing. The policy also forbids
/// pointing users from the app to an outside checkout, so while this is off
/// the app must not mention *where* a paid course could be bought.
///
/// Turn on only once the payment path is decided — see "Start here" in
/// `docs/LAUNCH_ANDROID.md`. Free courses are unaffected either way.
const bool kPaidCheckoutEnabled = false;
