import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/controller/teacher_controller.dart';
import 'package:padi_learn/screens/components/course_thumbnail.dart';
import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/teacher/components/teacher_course_card.dart';
import 'package:padi_learn/screens/teacher/editCourse_screen.dart';
import 'package:padi_learn/screens/teacher/lesson_editor_screen.dart';
import 'package:padi_learn/screens/videoplayer/components/comments_section.dart';
import 'package:padi_learn/services/course_service.dart';
import 'package:padi_learn/services/lesson_service.dart';
import 'package:padi_learn/services/supabase_storage_service.dart';
import 'package:padi_learn/services/transaction_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Everything a teacher does with one course: see how it is performing, read
/// and moderate what students are asking, edit it, take it down.
///
/// Takes an id rather than a row so it can be opened from a notification as
/// well as from the course list.
class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Map<String, dynamic>? _course;
  bool _loading = true;
  bool _busy = false;

  /// Real revenue for this course, summed from the payment ledger. Null while
  /// loading or if the query failed — never guessed from price × students.
  double? _revenue;
  int _salesCount = 0;

  List<Lesson> _lessons = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final course = await CourseService.fetch(widget.courseId);
      if (mounted) setState(() => _course = course);
    } catch (_) {
      // Leave _course null; the body renders a "couldn't load" state.
    }

    try {
      final sales = await TransactionService.salesForCourse(widget.courseId);
      if (mounted) {
        setState(() {
          _revenue = TransactionService.totalEarnings(sales);
          _salesCount = sales.length;
        });
      }
    } catch (_) {
      // Non-fatal: the tile shows a dash rather than a made-up number.
    }

    await _loadLessons();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadLessons() async {
    try {
      final lessons = await LessonService.forCourse(widget.courseId);
      if (mounted) setState(() => _lessons = lessons);
    } catch (_) {
      // Leave the previous list.
    }
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  /// Keeps the dashboard/list counters in step after a change.
  Future<void> _refreshTeacherData() async {
    if (Get.isRegistered<TeacherController>()) {
      await Get.find<TeacherController>().reload();
    }
  }

  Future<void> _openEditor() async {
    final course = _course;
    if (course == null) return;

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditCourseScreen(
          courseId: widget.courseId,
          courseData: course,
        ),
      ),
    );
    if (changed == true) {
      await _load();
      await _refreshTeacherData();
    }
  }

  Future<void> _toggleArchive() async {
    final course = _course;
    if (course == null) return;
    final archived = course['archived_at'] != null;

    if (!archived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Archive course'),
          content: const Text(
            'It will be removed from the marketplace so nobody new can buy it. '
            'Students who already enrolled keep their access, and you can put '
            'it back at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy = true);
    try {
      if (archived) {
        await CourseService.unarchive(widget.courseId);
        _notify('Course is live again.');
      } else {
        await CourseService.archive(widget.courseId);
        _notify('Course archived.');
      }
      await _load();
      await _refreshTeacherData();
    } catch (e) {
      _notify('Could not update the course: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final course = _course;
    if (course == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete course'),
        content: const Text(
          'This permanently removes the course and its video. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await CourseService.delete(course);
      await _refreshTeacherData();
      if (!mounted) return;
      Navigator.pop(context, true);
      _notify('Course deleted.');
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''), isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = _course;
    final archived = course?['archived_at'] != null;
    final students = (course?['enrollments'] as num?)?.toInt() ?? 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F8FA),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: AppColors.richBlack),
          title: Text(
            (course?['title'] ?? 'Course').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: AppColors.richBlack,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (course != null)
              PopupMenuButton<String>(
                enabled: !_busy,
                icon: const Icon(Icons.more_vert, color: AppColors.richBlack),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _openEditor();
                      break;
                    case 'archive':
                      _toggleArchive();
                      break;
                    case 'delete':
                      _delete();
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit course')),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(archived ? 'Make it live again' : 'Archive'),
                  ),
                  // Deleting cascades to enrollments, so it is only offered
                  // while nobody would lose access.
                  if (students == 0)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
          ],
          bottom: TabBar(
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: AppColors.fontGrey,
            indicatorColor: AppColors.primaryColor,
            labelStyle: GoogleFonts.poppins(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
            tabs: [
              const Tab(text: 'Overview'),
              Tab(text: _lessons.isEmpty ? 'Lessons' : 'Lessons (${_lessons.length})'),
              const Tab(text: 'Q&A'),
            ],
          ),
        ),
        body: _loading
            ? const AppLoader()
            : course == null
                ? _couldNotLoad()
                : TabBarView(
                    children: [
                      _buildOverview(course),
                      _buildLessons(),
                      _buildComments(course),
                    ],
                  ),
      ),
    );
  }

  Widget _couldNotLoad() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40.sp, color: AppColors.lightGrey),
            SizedBox(height: 12.h),
            Text(
              'Could not load this course.',
              style: GoogleFonts.poppins(
                  fontSize: 13.sp, color: AppColors.fontGrey),
            ),
            SizedBox(height: 16.h),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Overview
  // ---------------------------------------------------------------------------

  Widget _buildOverview(Map<String, dynamic> course) {
    final price = (course['price'] as num?)?.toDouble() ?? 0;
    final students = (course['enrollments'] as num?)?.toInt() ?? 0;
    final ratingAvg = (course['rating_avg'] as num?)?.toDouble() ?? 0;
    final ratingCount = (course['rating_count'] as num?)?.toInt() ?? 0;
    final archived = course['archived_at'] != null;

    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
        children: [
          _thumbnailHeader(course, archived),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  Icons.people_outline,
                  'Students',
                  '$students',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _statTile(
                  Icons.payments_outlined,
                  _salesCount == 1 ? 'Earned · 1 sale' : 'Earned · $_salesCount sales',
                  _revenue == null
                      ? '—'
                      : 'NGN ${_revenue!.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  Icons.star_outline_rounded,
                  'Rating',
                  ratingCount == 0
                      ? 'No ratings'
                      : '${ratingAvg.toStringAsFixed(1)} · $ratingCount',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _statTile(
                  Icons.sell_outlined,
                  'Price',
                  price == 0 ? 'Free' : 'NGN ${price.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _section(
            'About this course',
            Text(
              (course['description'] ?? 'No description yet.').toString(),
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                height: 1.6,
                color: AppColors.fontGrey,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          _section(
            'Details',
            Column(
              children: [
                _detailRow('Category',
                    (course['category'] ?? 'Uncategorised').toString()),
                _detailRow(
                  'Lessons',
                  [
                    '${_lessons.length}',
                    if (LessonService.totalDurationLabel(_lessons) != null)
                      LessonService.totalDurationLabel(_lessons)!,
                  ].join(' · '),
                ),
                _detailRow('Status', archived ? 'Archived' : 'Live'),
                _detailRow('Created', _formatDate(course['created_at'])),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          PrimaryButton(
            label: 'Edit course',
            isLoading: _busy,
            onPressed: _openEditor,
          ),
          SizedBox(height: 10.h),
          TextButton.icon(
            onPressed: _busy ? null : _toggleArchive,
            icon: Icon(
              archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              size: 18.sp,
              color: AppColors.fontGrey,
            ),
            label: Text(
              archived ? 'Make it live again' : 'Archive this course',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: AppColors.fontGrey,
              ),
            ),
          ),
          if (archived)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                'Archived courses stay available to the '
                '$students student${students == 1 ? '' : 's'} who already have them.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  color: AppColors.fontGrey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumbnailHeader(Map<String, dynamic> course, bool archived) {
    final thumbnail = (course['thumbnail_url'] ?? '').toString();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CourseThumbnail(url: thumbnail, iconSize: 34),
          ),
          Positioned(
            top: 10.h,
            left: 10.w,
            child: CourseStatusChip(archived: archived),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: AppColors.primaryColor),
          SizedBox(height: 8.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.richBlack,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              color: AppColors.fontGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.appWhite,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.richBlack,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5.sp,
              color: AppColors.fontGrey,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.richBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic iso) {
    final date = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ---------------------------------------------------------------------------
  // Lessons
  // ---------------------------------------------------------------------------

  Future<void> _addLesson() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonEditorScreen(courseId: widget.courseId),
      ),
    );
    if (added == true) await _loadLessons();
  }

  Future<void> _editLesson(Lesson lesson) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonEditorScreen(
          courseId: widget.courseId,
          lesson: lesson,
        ),
      ),
    );
    if (saved == true) await _loadLessons();
  }

  Future<void> _deleteLesson(Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete lesson'),
        content: Text(
          '"${lesson.title}" and its video will be removed permanently. '
          'Students who bought this course will no longer see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await LessonService.delete(lesson.id);
      await removeStoredObject(lesson.videoPath,
          fallbackBucket: kCourseMediaBucket);
      await _loadLessons();
      _notify('Lesson deleted.');
    } catch (e) {
      _notify('Could not delete the lesson: $e', isError: true);
    }
  }

  /// Persists a drag-and-drop reorder. The list is updated optimistically and
  /// reloaded from the server if the write fails.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final reordered = [..._lessons];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() => _lessons = reordered);

    try {
      await LessonService.reorder(reordered);
    } catch (e) {
      _notify('Could not save the new order: $e', isError: true);
      await _loadLessons();
    }
  }

  Widget _buildLessons() {
    if (_lessons.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_add,
                  size: 48.sp, color: AppColors.lightGrey),
              SizedBox(height: 14.h),
              Text(
                'No lessons yet',
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.richBlack,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'A course needs at least one lesson before students can get '
                'anything out of it.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12.5.sp, color: AppColors.fontGrey),
              ),
              SizedBox(height: 20.h),
              PrimaryButton(
                label: 'Add the first lesson',
                isLoading: false,
                onPressed: _addLesson,
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
      itemCount: _lessons.length,
      onReorder: _onReorder,
      header: Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Drag to reorder',
                style: GoogleFonts.poppins(
                    fontSize: 11.5.sp, color: AppColors.fontGrey),
              ),
            ),
            TextButton.icon(
              onPressed: _addLesson,
              icon: Icon(Icons.add, size: 18.sp, color: AppColors.primaryColor),
              label: Text(
                'Add lesson',
                style: GoogleFonts.poppins(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context, index) {
        final lesson = _lessons[index];
        return Padding(
          key: ValueKey(lesson.id),
          padding: EdgeInsets.only(bottom: 10.h),
          child: _lessonTile(lesson, index + 1),
        );
      },
    );
  }

  Widget _lessonTile(Lesson lesson, int number) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryAccent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.richBlack,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    if (!lesson.hasVideo)
                      Text(
                        'No video',
                        style: GoogleFonts.poppins(
                            fontSize: 10.5.sp, color: Colors.redAccent),
                      )
                    else
                      Text(
                        lesson.durationLabel ?? 'Video ready',
                        style: GoogleFonts.poppins(
                            fontSize: 10.5.sp, color: AppColors.fontGrey),
                      ),
                    if (lesson.isPreview) ...[
                      SizedBox(width: 8.w),
                      Text(
                        'Preview',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18.sp, color: AppColors.fontGrey),
            onSelected: (value) {
              if (value == 'edit') _editLesson(lesson);
              if (value == 'delete') _deleteLesson(lesson);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Q&A
  // ---------------------------------------------------------------------------

  Widget _buildComments(Map<String, dynamic> course) {
    // Reuses the student-facing section: passing the course's real owner id is
    // what unlocks the pin and moderate controls for them, and RLS enforces
    // the rest.
    final ownerId = (course['user_id'] ?? '').toString();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
      child: CommentsSection(
        courseId: widget.courseId,
        ownerId: ownerId.isEmpty ? null : ownerId,
      ),
    );
  }
}
