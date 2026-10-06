/// Links that re-enter the app from outside it.
///
/// Not secret, so unlike `supabase_config.dart` this is checked in — but each
/// one has to be listed under **Authentication → URL Configuration → Redirect
/// URLs** in the Supabase dashboard, or Supabase refuses the redirect and the
/// user lands on the project's default site URL instead of back in the app.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'web_links.dart';

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

  /// Where the password-reset email should return to, for the platform in hand.
  ///
  /// A browser cannot follow `padilearn://` — there is no app to hand it to —
  /// so sending the mobile deep link from a web signup means Supabase falls
  /// back to the Site URL and the user lands on the marketing site, with the
  /// recovery token stranded and no way to set a password. Web therefore
  /// returns to the app's own origin, where `supabase_flutter` reads the
  /// session out of the URL and `main.dart` routes on `passwordRecovery`.
  ///
  /// Both values must be listed under **Authentication → URL Configuration →
  /// Redirect URLs**: `padilearn://reset-callback` and
  /// `https://app.padilearn.com/**`.
  static String get passwordResetRedirect =>
      kIsWeb ? WebLinks.app : passwordReset;
}
