import 'package:flutter/material.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Load persisted settings before the first build so the theme is correct.
  final prefs = await SharedPreferences.getInstance();
  Get.put(SettingsController()).hydrate(prefs);

  // Initialize GetX controllers
  Get.lazyPut(() => CoursesController()); 
  Get.lazyPut(() => MarketplaceController());
  Get.lazyPut(() => UserController());
  Get.lazyPut(() => TeacherController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryColor,
        primary: AppColors.primaryColor,
        brightness: brightness,
      ),
      useMaterial3: true,
      fontFamily: 'Montserrat',
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
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: settings.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}