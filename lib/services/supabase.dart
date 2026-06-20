import 'package:supabase_flutter/supabase_flutter.dart';

/// Convenience accessor for the initialized Supabase client.
///
/// Use this everywhere instead of `Supabase.instance.client` so the dependency
/// is easy to find and swap in tests.
SupabaseClient get supabase => Supabase.instance.client;
