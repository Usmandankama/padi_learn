/// Template for the git-ignored `supabase_config.dart`.
///
/// Copy this file to `supabase_config.dart` and fill in the values. The
/// Supabase pair comes from Dashboard → Project Settings → API; the Google
/// client IDs from Google Cloud Console → APIs & Services → Credentials.
///
/// Note: the publishable key is a client-side key whose access is fully
/// constrained by Row Level Security, so it is safe to ship in the app. The
/// `service_role` key must NEVER be placed here.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://YOUR-PROJECT-REF.supabase.co';
  static const String publishableKey = 'sb_publishable_YOUR_KEY';

  /// OAuth client of type **Web application**.
  ///
  /// Despite the name it is what Android passes as `serverClientId`, and it is
  /// the audience Supabase validates the returned ID token against — so the
  /// same value must also be listed under Authentication → Providers → Google
  /// → "Authorized Client IDs" in the Supabase dashboard.
  ///
  /// Leave empty to hide the Google button rather than ship one that fails.
  static const String googleWebClientId = '';

  /// OAuth client of type **iOS**, matched to the bundle ID.
  ///
  /// Its reversed form (`com.googleusercontent.apps.…`) must also be
  /// registered as a URL scheme in `ios/Runner/Info.plist`.
  static const String googleIosClientId = '';
}
