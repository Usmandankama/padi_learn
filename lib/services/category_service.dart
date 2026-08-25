import 'package:padi_learn/services/supabase.dart';

/// A course category.
class Category {
  final String name;

  /// False when a teacher suggested it and it has not been approved yet. Such
  /// a category still labels its course, but never appears as a browse filter.
  final bool isActive;

  const Category({required this.name, required this.isActive});

  factory Category.fromRow(Map<String, dynamic> row) => Category(
        name: (row['name'] ?? '').toString(),
        isActive: row['is_active'] == true,
      );
}

/// Reads the category list, and lets teachers propose new ones.
///
/// Categories live in the database rather than in the app, so widening the
/// catalogue is an INSERT instead of a release. RLS returns the approved list
/// plus anything the caller suggested themselves.
class CategoryService {
  /// Everything the signed-in user may pick from: the approved list, plus
  /// their own pending suggestions.
  static Future<List<Category>> forPicker() async {
    final rows = await supabase
        .from('categories')
        .select('name, is_active')
        .order('position', ascending: true)
        .order('name', ascending: true);

    return rows.map((row) => Category.fromRow(Map<String, dynamic>.from(row))).toList();
  }

  /// Approved categories only — what the marketplace offers as filters.
  ///
  /// A pending suggestion must not become a browse filter, or one teacher's
  /// typo becomes a permanent chip everybody sees.
  static Future<List<String>> forBrowse() async {
    final rows = await supabase
        .from('categories')
        .select('name')
        .eq('is_active', true)
        .order('position', ascending: true)
        .order('name', ascending: true);

    return rows.map((row) => (row['name'] ?? '').toString()).toList();
  }

  /// Proposes a new category and returns its name.
  ///
  /// RLS pins the row to `is_active = false` and to the caller, so this can
  /// only ever suggest — never approve. Re-suggesting an existing name simply
  /// returns it.
  static Future<String> suggest(String rawName) async {
    final name = _normalise(rawName);
    if (name.isEmpty) {
      throw Exception('Please enter a category name.');
    }

    final existing = await supabase
        .from('categories')
        .select('name')
        .ilike('name', name)
        .maybeSingle();
    if (existing != null) return (existing['name'] ?? name).toString();

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('You must be signed in.');

    final row = await supabase
        .from('categories')
        .insert({
          'name': name,
          'is_active': false,
          'suggested_by': uid,
          // Sorts below the curated list wherever it does appear.
          'position': 900,
        })
        .select('name')
        .single();

    return (row['name'] ?? name).toString();
  }

  /// Trims and title-cases, so "  data science " and "DATA SCIENCE" don't
  /// become two entries the moment someone types casually.
  static String _normalise(String value) {
    final collapsed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return '';
    return collapsed
        .split(' ')
        .map((word) => word.length <= 2 && word != word.toUpperCase()
            ? word.toLowerCase()
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }
}
