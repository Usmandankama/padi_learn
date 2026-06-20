import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:padi_learn/config/supabase_config.dart';
import 'package:padi_learn/controller/course_controller.dart';
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

  Get.lazyPut(() => CoursesController(), fenix: true);
  Get.lazyPut(() => MarketplaceController(), fenix: true);
  Get.lazyPut(() => UserController(), fenix: true);
  Get.lazyPut(() => TeacherController(), fenix: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryColor,
              primary: AppColors.primaryColor,
              onPrimary: AppColors.appWhite,
              secondary: AppColors.primaryColor,
              onSecondary: AppColors.appWhite,
            ),
            useMaterial3: true,
            fontFamily: 'Montserrat',
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
