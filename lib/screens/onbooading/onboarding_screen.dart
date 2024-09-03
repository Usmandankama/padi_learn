import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/screens/login/login_screen.dart';
import 'package:padi_learn/utils/colors.dart';
import '../../models/onboarding_page.dart'; // Import the OnboardingPage widget

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      body: PageView(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: <Widget>[
          const OnboardingPage(
            title: 'Learn Anytime, Anywhere',
            description:
                'Access a wealth of knowledge from the comfort of your home.',
            imagePath: 'assets/images/remote_work.png',
          ),
          const OnboardingPage(
            title: 'Interactive Lessons',
            description:
                'Engage with interactive content to enhance your learning experience.',
            imagePath: 'assets/images/progress.png',
          ),
          OnboardingPage(
            title: 'Track Your Progress',
            description:
                'Monitor your learning journey with easy-to-use progress tracking tools.',
            imagePath: 'assets/images/progress.png',
            isLastPage: true,
            onGetStarted: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),
      bottomSheet: _currentPage == 2
          ? Container(
              decoration: const BoxDecoration(
                color: AppColors.appWhite,
              ),
              padding: const EdgeInsets.all(25.0),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(AppColors.primaryColor),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 80.0, vertical: 20),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                },
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: AppColors.appWhite,
                  ),
                ),
              ),
            )
          : Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      _pageController.jumpToPage(2); // Skip to last page
                    },
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(3, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: _currentPage == index ? 12.0 : 8.0,
                        height: _currentPage == index ? 12.0 : 8.0,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primaryColor
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      );
                    }),
                  ),
                  TextButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      );
                    },
                    child: Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
