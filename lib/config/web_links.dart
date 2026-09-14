/// Pages on padilearn.com that the app links to or sends people to.
///
/// The site's source is `website/` in this repo. If a page moves there, change
/// it here too — a broken privacy-policy link is a Play Store rejection.
library;

class WebLinks {
  const WebLinks._();

  static const String site = 'https://padilearn.com';

  static const String privacyPolicy = '$site/privacy';
  static const String terms = '$site/terms';

  /// Play's account-deletion URL. The in-app flow lives on the profile screen.
  static const String deleteAccount = '$site/delete-account';

  /// Where sign-up confirmation and email-change links land after Supabase has
  /// verified them.
  ///
  /// A web page rather than a deep link on purpose: people open these emails
  /// on laptops as often as phones, and a `padilearn://` link does nothing on
  /// a laptop. The address is confirmed by Supabase before the redirect, so
  /// the page only has to say so and send them back to the app to log in.
  ///
  /// Must be listed under **Authentication → URL Configuration → Redirect
  /// URLs** in the Supabase dashboard, or Supabase ignores it and falls back
  /// to the Site URL.
  static const String emailConfirmed = '$site/email-confirmed';
}
