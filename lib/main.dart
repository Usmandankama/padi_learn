import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:padi_learn/config/supabase_config.dart';
import 'package:padi_learn/controller/course_controller.dart';
import 'package:padi_learn/controller/settings_controller.dart';
import 'package:padi_learn/controller/teacher_controller.dart';
import 'controller/marketplace_controller.dart';
import 'controller/user_controller.dart';
import 'screens/onboarding/splash_screen.dart';
import 'utils/colors.dart';
import 'dart:async';
import 'package:padi_learn/screens/forgot_password/reset_password_screen.dart';
import 'package:padi_learn/services/supabase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Load persisted settings before the first build so the theme is correct.
  // Marked permanent so signing out (which disposes every other controller)
  // can't take the app's theme with it.
  final prefs = await SharedPreferences.getInstance();
  Get.put(SettingsController(), permanent: true).hydrate(prefs);

  registerAppControllers();

  runApp(const MyApp());
}

/// Registers the user-scoped GetX controllers.
///
/// `fenix: true` is what makes sign-out safe: `Get.deleteAll()` disposes the
/// live instances (so the next user never sees the previous one's data) but
/// keeps these registrations, and each controller is rebuilt — re-running
/// `onInit` against the new session — on the next `Get.find`. Without it the
/// registrations are erased and every `Get.find` after a sign-out throws.
void registerAppControllers() {
  Get.lazyPut(() => CoursesController(), fenix: true);
  Get.lazyPut(() => MarketplaceController(), fenix: true);
  Get.lazyPut(() => UserController(), fenix: true);
  Get.lazyPut(() => TeacherController(), fenix: true);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Opening the emailed reset link signs the user into a short-lived
    // recovery session and fires this event. It is the only signal that the
    // link was followed, so without it the deep link just resolves to whatever
    // screen the session lands on — with no way to actually set a password.
    _authSub = supabase.auth.onAuthStateChange.listen((state) {
      if (state.event != AuthChangeEvent.passwordRecovery) return;
      if (Get.currentRoute.contains('ResetPasswordScreen')) return;
      Get.to(() => const ResetPasswordScreen());
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// Builds a theme from one [AppPalette].
  ///
  /// Every Material default that paints a surface is pointed at the palette
  /// here, so a screen that simply *doesn't* set a colour comes out right in
  /// both themes. Only screens that hard-code one need touching — which is the
  /// whole reason dark mode was broken.
  ThemeData _theme(Brightness brightness, AppPalette palette) {
    final isDark = brightness == Brightness.dark;

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
      canvasColor: palette.surface,
      cardColor: palette.surface,
      dividerColor: palette.hairline,
      dividerTheme: DividerThemeData(color: palette.hairline, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.ground,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: palette.ink),
        // Light content in the status bar on a dark ground, and vice versa.
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      listTileTheme: ListTileThemeData(
        textColor: palette.ink,
        iconColor: palette.inkSoft,
      ),
      iconTheme: IconThemeData(color: palette.ink),
      dialogTheme: DialogThemeData(backgroundColor: palette.surface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(color: palette.surface),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: TextStyle(color: palette.ground),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceAlt,
        hintStyle: TextStyle(color: palette.inkSoft),
        labelStyle: TextStyle(color: palette.inkSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.hairline),
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primaryColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          // Binds the palette above the Navigator, so it is set before any
          // screen builds and re-set whenever the theme changes.
          builder: (context, child) {
            AppColors.bind(Theme.of(context));
            return child ?? const SizedBox.shrink();
          },
          theme: _theme(Brightness.light, AppPalette.light),
          darkTheme: _theme(Brightness.dark, AppPalette.dark),
          themeMode: settings.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
