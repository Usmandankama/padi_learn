import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/controller/teacher_controller.dart';
import 'package:padi_learn/screens/notifications/notification_bell.dart';
import 'package:padi_learn/screens/teacher/components/earning_widget.dart';
import 'package:padi_learn/screens/teacher/course_detail_screen.dart';
import 'package:padi_learn/screens/teacher/create_course_screen.dart';
import 'package:padi_learn/services/notification_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// The teacher's home: how the business is doing, and what needs attention.
///
/// It deliberately does not list courses — that is the Courses tab's job. This
/// screen links there instead of rendering the same grid a second time.
class TeacherDashboardScreen extends StatefulWidget {
  /// Switches the shell to the Courses tab. Null when the dashboard is opened
  /// outside the bottom-nav shell.
  final VoidCallback? onOpenCourses;

  const TeacherDashboardScreen({super.key, this.onOpenCourses});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  // Get.find, not Get.put: main() registers this with `fenix: true` so it
  // survives sign-out, and a Get.put here replaced that registration with a
  // non-fenix one — after which every other screen's Get.find threw. It also
  // built a fresh controller (and re-ran all three fetches) each time this
  // tab was rebuilt.
  final TeacherController controller = Get.find<TeacherController>();

  /// Built once — creating it in `build` resubscribed on every rebuild.
  late final Stream<List<Map<String, dynamic>>> _activity =
      NotificationService.stream();

  Future<void> _createCourse() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateCourseScreen()),
    );
    await controller.reload();
  }

  void _openCourse(String courseId) {
    if (courseId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: courseId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    return Scaffold(
      backgroundColor: AppColors.palette.ground,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(
            color: AppColors.primaryColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [NotificationBell()],
        backgroundColor: AppColors.palette.ground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryColor,
        onRefresh: controller.reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 32.h),
          children: [
            const EarningsWidget(),
            SizedBox(height: 20.h),
            _buildCoursesCard(),
            SizedBox(height: 20.h),
            _sectionHeader('Recent activity'),
            SizedBox(height: 10.h),
            _buildActivity(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.palette.ink,
      ),
    );
  }

  Widget _buildCoursesCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.palette.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.video_library_outlined,
                  size: 22.sp, color: AppColors.primaryColor),
              SizedBox(width: 10.w),
              Expanded(
                child: Obx(
                  () => Text(
                    // Counts archived courses too, so "published" would be
                    // inaccurate here.
                    controller.totalCoursesUploaded.value == 1
                        ? '1 course'
                        : '${controller.totalCoursesUploaded.value} courses',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.palette.ink,
                    ),
                  ),
                ),
              ),
              if (widget.onOpenCourses != null)
                TextButton(
                  onPressed: widget.onOpenCourses,
                  child: Text(
                    'Manage',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _createCourse,
              icon: Icon(Icons.add, size: 18.sp),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                side: const BorderSide(color: AppColors.primaryColor),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              label: Text(
                'New course',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Enrollments and comments both arrive as notification rows written by
  /// database triggers, so one stream covers the whole feed. (A teacher cannot
  /// read the `enrollments` table directly — RLS limits that to the student who
  /// owns the row — which is exactly why the triggers denormalise into
  /// `notifications`.)
  Widget _buildActivity() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _activity,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
            ),
          );
        }

        final items = (snapshot.data ?? const []).take(8).toList();
        if (items.isEmpty) return _emptyActivity();

        return Column(
          children: [
            for (final item in items) ...[
              _activityTile(item),
              SizedBox(height: 8.h),
            ],
          ],
        );
      },
    );
  }

  Widget _emptyActivity() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.palette.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 30.sp, color: AppColors.palette.hairline),
          SizedBox(height: 8.h),
          Text(
            'No activity yet. Enrollments and student questions will show up here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: AppColors.palette.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> item) {
    final isComment = item['type'] == 'comment';
    final unread = item['is_read'] != true;
    final courseId = (item['course_id'] ?? '').toString();

    return GestureDetector(
      onTap: () => _openCourse(courseId),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.palette.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: unread ? AppColors.primaryAccent : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isComment
                    ? Icons.chat_bubble_outline
                    : Icons.person_add_alt_1_outlined,
                size: 17.sp,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['message'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5.sp,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: AppColors.palette.ink,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _timeAgo(item['created_at']),
                    style: GoogleFonts.poppins(
                      fontSize: 10.5.sp,
                      color: AppColors.palette.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20.sp, color: AppColors.palette.inkSoft),
          ],
        ),
      ),
    );
  }

  String _timeAgo(dynamic iso) {
    final date = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
