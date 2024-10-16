import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:padi_learn/controller/course_controller.dart';
import 'package:padi_learn/controller/teacherController.dart';
import 'controller/marketplace_controller.dart';
import 'controller/user_controller.dart';
import 'screens/onbooading/spalsh_screen.dart';
import 'utils/colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

// Initialize GetX controllers
  Get.lazyPut(()=>CoursesController());  // Course Controller
  Get.lazyPut(()=>MarketplaceController());  // Marketplace Controller
  Get.lazyPut(()=>UserController());
  Get.lazyPut(()=>TeacherDashboardController());  // Othe

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