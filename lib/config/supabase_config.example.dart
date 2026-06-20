/// Template for Supabase credentials.
///
/// Copy this file to `supabase_config.dart` (which is git-ignored) and fill in
/// your project's values from Supabase Dashboard → Project Settings → API.
///
/// The publishable key is a client-side key protected by Row Level Security and
/// is safe to ship. Never put the `service_role` key in the app.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://YOUR-PROJECT.supabase.co';
  static const String publishableKey = 'YOUR-SUPABASE-PUBLISHABLE-KEY';
}
