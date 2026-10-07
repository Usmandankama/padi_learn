import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/config/supabase_config.dart';
import 'package:padi_learn/utils/colors.dart';

import 'admin_gate.dart';

/// The admin app: a second entry point into this codebase, built and deployed
/// on its own (docs/ADMIN_PANEL.md, items 11–14).
///
///   flutter run -d chrome -t lib/admin/main.dart
///   flutter build web --release -t lib/admin/main.dart
///
/// It shares the Supabase client, palette and models with the student and
/// teacher app, but nothing outside lib/admin imports it, so tree shaking keeps
/// every admin screen out of the public bundle.
///
/// Nothing here is trusted for authorisation. Every admin function checks
/// `assert_admin()` in the database; this app only decides what to draw.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Also the browser tab's title on web.
      title: 'PadiLearn Admin',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light, AppPalette.light),
      darkTheme: _theme(Brightness.dark, AppPalette.dark),
      home: const AdminGate(),
    );
  }
}

/// A smaller cousin of the theme in lib/main.dart: the same palette and brand,
/// without the phone-only machinery (ScreenUtil, the nav pill), because this
/// app is used on a laptop.
ThemeData _theme(Brightness brightness, AppPalette palette) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: palette.hairline),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Montserrat',
    brightness: brightness,
    extensions: <ThemeExtension<dynamic>>[palette],
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryColor,
      primary: AppColors.primaryColor,
      onPrimary: AppColors.appWhite,
      surface: palette.surface,
      onSurface: palette.ink,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: palette.ground,
    cardColor: palette.surface,
    dividerColor: palette.hairline,
    dividerTheme: DividerThemeData(color: palette.hairline, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.ground,
      foregroundColor: palette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.surface,
      indicatorColor: AppColors.primaryAccent,
      selectedIconTheme: const IconThemeData(color: AppColors.primaryColor),
      unselectedIconTheme: IconThemeData(color: palette.inkSoft),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceAlt,
      hintStyle: TextStyle(color: palette.inkSoft),
      labelStyle: TextStyle(color: palette.inkSoft),
      border: border,
      enabledBorder: border,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.ink,
      contentTextStyle: TextStyle(color: palette.ground),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
