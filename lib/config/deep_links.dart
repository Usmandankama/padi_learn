/// Links that re-enter the app from outside it.
///
/// Not secret, so unlike `supabase_config.dart` this is checked in — but each
/// one has to be listed under **Authentication → URL Configuration → Redirect
/// URLs** in the Supabase dashboard, or Supabase refuses the redirect and the
/// user lands on the project's default site URL instead of back in the app.
library;

class DeepLinks {
  const DeepLinks._();

  /// Custom scheme registered in `AndroidManifest.xml` (and, when iOS ships,
  /// in `Info.plist` under `CFBundleURLTypes`).
  static const String scheme = 'padilearn';

  /// Where the password-reset email returns to.
  ///
  /// Without this the reset mail redirects to Supabase's site URL — a web page
  /// that has no idea this app exists — so the user could open the link but
  /// never actually set a new password. That was the whole bug.
  static const String passwordReset = '$scheme://reset-callback';
}
