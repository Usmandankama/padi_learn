import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/controller/course_controller.dart';
import 'package:padi_learn/controller/marketplace_controller.dart';
import 'package:padi_learn/controller/user_controller.dart';
import 'package:padi_learn/screens/description/course_description_screen.dart';
import 'package:padi_learn/screens/marketplace/components/course_card.dart';
import 'package:padi_learn/screens/marketplace/marketplace_screen.dart';
import 'package:padi_learn/screens/student/components/ongoingCourses.dart';
import 'package:padi_learn/utils/colors.dart';

const double _kGap16 = 16;
const double _kGap24 = 24;

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final MarketplaceController _marketController =
      Get.find<MarketplaceController>();
  final UserController _userController = Get.find<UserController>();

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openCourse(Map<String, dynamic> course) {
    Get.find<CoursesController>().selectCourse(
      (course['id'] ?? '').toString(),
      (course['title'] ?? '').toString(),
      (course['thumbnail_url'] ?? '').toString(),
      (course['price'] as num?) ?? 0,
      (course['description'] ?? '').toString(),
      (course['author'] ?? '').toString(),
      (course['video_url'] ?? '').toString(),
    );
    Get.to(() => CourseDescriptionScreen());
  }

  void _goToMarketplace() {
    Get.to(() => const MarketplaceScreen(userRole: 'Student'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: _kGap24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: _kGap16.h),
              _buildSearchBar(),
              SizedBox(height: _kGap16.h),
              _buildFeaturedBanner(),
              SizedBox(height: _kGap24.h),
              _buildSectionHeader('Continue Learning'),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _kGap16.w),
                child: OngoingCoursesWidget(
                  userId: _userController.userId.value,
                ),
              ),
              SizedBox(height: _kGap24.h),
              _buildSectionHeader('Popular Courses', onSeeAll: _goToMarketplace),
              SizedBox(height: 12.h),
              _buildPopularGrid(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(_kGap16.w, 8.h, _kGap16.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: AppColors.fontGrey,
                  ),
                ),
                SizedBox(height: 2.h),
                Obx(
                  () => Text(
                    _userController.userName.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.richBlack,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildNotificationBell(),
          SizedBox(width: 12.w),
          _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.notifications_none_rounded,
              color: AppColors.richBlack),
          Positioned(
            top: 12.h,
            right: 13.w,
            child: Container(
              width: 7.w,
              height: 7.w,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Obx(() {
      final url = _userController.profileImageUrl.value;
      final name = _userController.userName.value.trim();
      final initial = name.isNotEmpty && name != 'Loading...'
          ? name.substring(0, 1).toUpperCase()
          : '?';
      return Container(
        width: 44.w,
        height: 44.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryAccent,
          shape: BoxShape.circle,
          image: url.isNotEmpty
              ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
              : null,
        ),
        child: url.isNotEmpty
            ? null
            : Text(
                initial,
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryColor,
                ),
              ),
      );
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _kGap16.w),
      child: GestureDetector(
        onTap: _goToMarketplace,
        child: Container(
          height: 50.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.appWhite,
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.primaryColor),
              SizedBox(width: 10.w),
              Text(
                'Search courses',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: AppColors.fontGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _kGap16.w),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryColor, Color(0xFF267A5A)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sharpen your skills',
                    style: GoogleFonts.poppins(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Explore courses from top instructors and learn at your own pace.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5.sp,
                      height: 1.4,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  GestureDetector(
                    onTap: _goToMarketplace,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        'Browse courses',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(Icons.school_rounded,
                size: 64.sp, color: Colors.white.withOpacity(0.85)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _kGap16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.richBlack,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'See all',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPopularGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _kGap16.w),
      child: Obx(() {
        final courses = _marketController.courses.toList();

        if (courses.isEmpty) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: _gridDelegate(),
            itemBuilder: (_, __) => const CourseCardShimmer(),
          );
        }

        // Most popular first, capped at 6 for the home page.
        courses.sort((a, b) => ((b['enrollments'] as num?) ?? 0)
            .compareTo((a['enrollments'] as num?) ?? 0));
        final popular = courses.take(6).toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: popular.length,
          gridDelegate: _gridDelegate(),
          itemBuilder: (context, i) {
            final course = popular[i];
            return CourseCard(
              course: course,
              onTap: () => _openCourse(course),
            );
          },
        );
      }),
    );
  }

  SliverGridDelegateWithFixedCrossAxisCount _gridDelegate() {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 14.w,
      mainAxisSpacing: 16.h,
      childAspectRatio: 0.68,
    );
  }
}
