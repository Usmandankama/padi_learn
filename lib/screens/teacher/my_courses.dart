import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/controller/teacher_controller.dart';
import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/teacher/components/teacher_course_card.dart';
import 'package:padi_learn/screens/teacher/course_detail_screen.dart';
import 'package:padi_learn/screens/teacher/create_course_screen.dart';
import 'package:padi_learn/utils/colors.dart';

/// Which slice of the teacher's catalogue is on screen.
enum _CourseFilter { all, live, archived }

extension on _CourseFilter {
  String get label {
    switch (this) {
      case _CourseFilter.all:
        return 'All';
      case _CourseFilter.live:
        return 'Live';
      case _CourseFilter.archived:
        return 'Archived';
    }
  }
}

/// The teacher's course management hub.
///
/// This is the one place that lists their catalogue — the dashboard links here
/// rather than repeating the list.
class TeacherMyCoursesPage extends StatefulWidget {
  const TeacherMyCoursesPage({super.key});

  @override
  State<TeacherMyCoursesPage> createState() => _TeacherMyCoursesPageState();
}

class _TeacherMyCoursesPageState extends State<TeacherMyCoursesPage> {
  // Get.find, not Get.put: main() registers this with `fenix: true` so it
  // survives sign-out, and a Get.put here replaced that registration with a
  // non-fenix one — after which every other screen's Get.find threw. It also
  // built a fresh controller (and re-ran all three fetches) each time this
  // tab was rebuilt.
  final TeacherController controller = Get.find<TeacherController>();
  final TextEditingController _search = TextEditingController();

  /// Built once. Creating the stream inside `build` opened a new realtime
  /// subscription on every keystroke.
  late final Stream<List<Map<String, dynamic>>> _courses =
      controller.courseStream();

  _CourseFilter _filter = _CourseFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> courses) {
    final query = _search.text.trim().toLowerCase();
    return courses.where((course) {
      final archived = course['archived_at'] != null;
      switch (_filter) {
        case _CourseFilter.live:
          if (archived) return false;
          break;
        case _CourseFilter.archived:
          if (!archived) return false;
          break;
        case _CourseFilter.all:
          break;
      }
      if (query.isEmpty) return true;
      return (course['title'] ?? '').toString().toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openCourse(String courseId) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(courseId: courseId)),
    );
    if (deleted == true) await controller.reload();
  }

  Future<void> _createCourse() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateCourseScreen()),
    );
    await controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes; without this the screen keeps
    // painting the previous theme's colours when the mode flips.
    AppColors.watch(context);
    return Scaffold(
      backgroundColor: AppColors.palette.ground,
      appBar: AppBar(
        backgroundColor: AppColors.palette.ground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'My Courses',
          style: GoogleFonts.poppins(
            color: AppColors.primaryColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New course',
            onPressed: _createCourse,
            icon: const Icon(Icons.add, color: AppColors.primaryColor),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearch(),
          _buildFilters(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _courses,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoader();
                }
                if (snapshot.hasError) {
                  return _message(
                    Icons.cloud_off,
                    'Could not load your courses.',
                  );
                }

                final all = snapshot.data ?? const <Map<String, dynamic>>[];
                if (all.isEmpty) return _buildFirstCoursePrompt();

                final courses = _apply(all);
                if (courses.isEmpty) {
                  return _message(
                    Icons.search_off,
                    _search.text.trim().isEmpty
                        ? 'Nothing here yet.'
                        : 'No courses match "${_search.text.trim()}".',
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primaryColor,
                  onRefresh: controller.reload,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 32.h),
                    itemCount: courses.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (_, i) => TeacherCourseCard(
                      course: courses[i],
                      onTap: () =>
                          _openCourse((courses[i]['id'] ?? '').toString()),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.poppins(fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: 'Search your courses',
          hintStyle: GoogleFonts.poppins(
            fontSize: 13.sp,
            color: AppColors.palette.inkSoft,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryColor),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: AppColors.palette.inkSoft),
                  onPressed: () {
                    _search.clear();
                    setState(() {});
                  },
                ),
          filled: true,
          fillColor: AppColors.palette.surface,
          contentPadding: EdgeInsets.symmetric(vertical: 4.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 48.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        children: _CourseFilter.values.map((filter) {
          final selected = _filter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => setState(() => _filter = filter),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryColor
                      : AppColors.palette.surface,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  filter.label,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.appWhite
                        : AppColors.palette.inkSoft,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40.sp, color: AppColors.palette.hairline),
            SizedBox(height: 12.h),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: AppColors.palette.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstCoursePrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined,
                size: 52.sp, color: AppColors.palette.hairline),
            SizedBox(height: 16.h),
            Text(
              'You have not published a course yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.palette.ink,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Upload your first lesson and it will appear in the marketplace '
              'for students to buy.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5.sp,
                color: AppColors.palette.inkSoft,
              ),
            ),
            SizedBox(height: 24.h),
            PrimaryButton(
              label: 'Create your first course',
              isLoading: false,
              onPressed: _createCourse,
            ),
          ],
        ),
      ),
    );
  }
}
