import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/videoplayer/components/comments_section.dart';
import 'package:padi_learn/services/lesson_service.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/services/video_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Plays a course: one lesson at a time, with the curriculum underneath.
class VideoPlayerPage extends StatefulWidget {
  final String courseId;

  /// Optional lesson to open on. Defaults to the first unfinished one.
  final String? initialLessonId;

  const VideoPlayerPage({
    super.key,
    required this.courseId,
    this.initialLessonId,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  Map<String, dynamic> _course = {};
  List<Lesson> _lessons = const [];
  Map<String, LessonProgress> _progress = const {};
  Lesson? _current;

  bool _loading = true;
  bool _switching = false;
  String? _videoError;

  /// Bumped on every lesson switch so a slow load for a previous lesson can't
  /// overwrite the one the user has since chosen.
  int _loadToken = 0;

  /// Throttle: progress is written to the server at most once every 15s while
  /// playing, plus once when leaving the lesson.
  int _lastSyncedSecond = -1;
  static const int _syncEverySeconds = 15;

  int _userRating = 0;
  double _avgRating = 0;
  int _ratingCount = 0;
  bool _savingRating = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onTick);
    _syncProgress(force: true);
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadCourse();
    await _loadRatings();

    if (_lessons.isNotEmpty) {
      final initial = _pickInitialLesson();
      await _openLesson(initial);
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCourse() async {
    try {
      final course = await supabase
          .from('courses')
          .select()
          .eq('id', widget.courseId)
          .maybeSingle();
      if (course != null) _course = Map<String, dynamic>.from(course);

      _lessons = await LessonService.forCourse(widget.courseId);
      _progress = await LessonService.progressForCourse(widget.courseId);
    } catch (e) {
      debugPrint('Error loading course: $e');
    }
  }

  /// Resume where they left off: the first lesson they have not finished.
  Lesson _pickInitialLesson() {
    if (widget.initialLessonId != null) {
      for (final lesson in _lessons) {
        if (lesson.id == widget.initialLessonId) return lesson;
      }
    }
    for (final lesson in _lessons) {
      if (_progress[lesson.id]?.completed != true) return lesson;
    }
    return _lessons.first;
  }

  Future<void> _openLesson(Lesson lesson) async {
    // Persist where we got to in the outgoing lesson first.
    _syncProgress(force: true);

    final token = ++_loadToken;
    setState(() {
      _switching = true;
      _videoError = null;
      _current = lesson;
      _lastSyncedSecond = -1;
    });

    // Tear the old player down before building the new one.
    _videoController?.removeListener(_onTick);
    final oldChewie = _chewieController;
    final oldVideo = _videoController;
    _chewieController = null;
    _videoController = null;
    oldChewie?.dispose();
    await oldVideo?.dispose();

    try {
      final url = await VideoService.playbackUrl(lesson.id);
      if (!mounted || token != _loadToken) return;

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted || token != _loadToken) {
        await controller.dispose();
        return;
      }

      // Resume from the saved position, unless we are at the very end.
      final saved = _progress[lesson.id]?.positionSeconds ?? 0;
      if (saved > 0 && saved < controller.value.duration.inSeconds - 5) {
        await controller.seekTo(Duration(seconds: saved));
      }

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        showControlsOnInitialize: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.5, 1.0, 1.25, 1.5, 2.0],
        aspectRatio: controller.value.aspectRatio,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primaryColor,
          handleColor: AppColors.primaryColor,
          bufferedColor: AppColors.primaryAccent,
        ),
        deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
      );

      controller.addListener(_onTick);

      if (!mounted || token != _loadToken) {
        chewie.dispose();
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _chewieController = chewie;
        _switching = false;
      });
    } catch (e) {
      debugPrint('Error opening lesson: $e');
      if (!mounted || token != _loadToken) return;
      setState(() {
        _videoError =
            e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
        _switching = false;
      });
    }
  }

  void _onTick() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final seconds = controller.value.position.inSeconds;
    if (seconds == _lastSyncedSecond) return;
    if (seconds % _syncEverySeconds != 0) return;

    _lastSyncedSecond = seconds;
    _syncProgress();
  }

  /// Writes the current position for the current lesson. Fire-and-forget:
  /// playback must not stall because the network is slow, and a lost update is
  /// recovered by the next tick.
  void _syncProgress({bool force = false}) {
    final lesson = _current;
    final controller = _videoController;
    if (lesson == null || controller == null || !controller.value.isInitialized) {
      return;
    }

    final position = controller.value.position.inSeconds;
    final duration = controller.value.duration.inSeconds;
    if (!force && position <= 0) return;

    // Treat the last 5% as finished — few people watch the credits.
    final completed = duration > 0 && position >= (duration * 0.95);

    LessonService.saveProgress(
      lessonId: lesson.id,
      courseId: widget.courseId,
      positionSeconds: position,
      completed: completed,
    ).then((_) {
      if (!mounted) return;
      final previous = _progress[lesson.id];
      if (completed && previous?.completed != true) {
        setState(() {
          _progress = {
            ..._progress,
            lesson.id: LessonProgress(
              lessonId: lesson.id,
              positionSeconds: position,
              completed: true,
            ),
          };
        });
      }
    }).catchError((Object e) {
      debugPrint('Could not sync progress: $e');
    });
  }

  Future<void> _loadRatings() async {
    _avgRating = (_course['rating_avg'] as num?)?.toDouble() ?? 0;
    _ratingCount = (_course['rating_count'] as num?)?.toInt() ?? 0;

    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final mine = await supabase
          .from('course_ratings')
          .select('rating')
          .eq('user_id', uid)
          .eq('course_id', widget.courseId)
          .maybeSingle();
      _userRating = (mine?['rating'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // Non-critical.
    }
  }

  Future<void> _submitRating(int value) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;

    setState(() {
      _userRating = value;
      _savingRating = true;
    });

    try {
      await supabase.from('course_ratings').upsert({
        'user_id': uid,
        'course_id': widget.courseId,
        'rating': value,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,course_id');

      final updated = await supabase
          .from('courses')
          .select('rating_avg, rating_count')
          .eq('id', widget.courseId)
          .maybeSingle();
      if (updated != null && mounted) {
        setState(() {
          _avgRating = (updated['rating_avg'] as num?)?.toDouble() ?? _avgRating;
          _ratingCount =
              (updated['rating_count'] as num?)?.toInt() ?? _ratingCount;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for rating!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save rating: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingRating = false);
    }
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final completed =
        _progress.values.where((progress) => progress.completed).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.richBlack),
        title: Text(
          (_course['title'] ?? 'Course').toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: AppColors.richBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const AppLoader()
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVideo(),
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _current?.title ??
                              (_course['title'] ?? 'Course').toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.richBlack,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        _buildMetaRow(),
                        SizedBox(height: 20.h),
                        _buildCurriculum(completed),
                        SizedBox(height: 20.h),
                        _buildRatingCard(),
                        SizedBox(height: 20.h),
                        Text(
                          'About this course',
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.richBlack,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          (_course['description'] ?? 'No description available.')
                              .toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            height: 1.6,
                            color: AppColors.fontGrey,
                          ),
                        ),
                        SizedBox(height: 28.h),
                        const Divider(height: 1, color: AppColors.lightGrey),
                        SizedBox(height: 20.h),
                        CommentsSection(
                          courseId: widget.courseId,
                          ownerId: (_course['user_id'] ?? '').toString().isEmpty
                              ? null
                              : _course['user_id'].toString(),
                        ),
                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetaRow() {
    return Row(
      children: [
        Icon(Icons.person_outline, size: 16.sp, color: AppColors.fontGrey),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            'By ${(_course['author'] ?? 'Unknown')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 12.sp, color: AppColors.fontGrey),
          ),
        ),
        Icon(Icons.star_rounded, size: 16.sp, color: const Color(0xFFFFC107)),
        SizedBox(width: 3.w),
        Text(
          _ratingCount == 0
              ? 'No ratings'
              : '${_avgRating.toStringAsFixed(1)} ($_ratingCount)',
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.richBlack,
          ),
        ),
      ],
    );
  }

  Widget _buildVideo() {
    final ready = !_switching &&
        _chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized;

    return AspectRatio(
      aspectRatio: ready ? _videoController!.value.aspectRatio : 16 / 9,
      child: ready
          ? Chewie(controller: _chewieController!)
          : Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: _videoError == null
                  ? const AppLoader()
                  : Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline,
                              color: Colors.white70, size: 30.sp),
                          SizedBox(height: 10.h),
                          Text(
                            _videoError!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _buildCurriculum(int completedCount) {
    if (_lessons.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: AppColors.appWhite,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Text(
          'This course has no lessons yet.',
          textAlign: TextAlign.center,
          style:
              GoogleFonts.poppins(fontSize: 12.5.sp, color: AppColors.fontGrey),
        ),
      );
    }

    final total = LessonService.totalDurationLabel(_lessons);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Lessons',
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.richBlack,
              ),
            ),
            const Spacer(),
            Text(
              [
                '$completedCount of ${_lessons.length} done',
                if (total != null) total,
              ].join(' · '),
              style: GoogleFonts.poppins(
                  fontSize: 11.5.sp, color: AppColors.fontGrey),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.appWhite,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _lessons.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 56.w, color: AppColors.lightGrey),
                _buildLessonRow(_lessons[i], i + 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLessonRow(Lesson lesson, int number) {
    final isCurrent = _current?.id == lesson.id;
    final done = _progress[lesson.id]?.completed == true;

    return InkWell(
      onTap: isCurrent ? null : () => _openLesson(lesson),
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.primaryColor
                    : done
                        ? AppColors.primaryAccent
                        : const Color(0xFFF1F2F4),
                shape: BoxShape.circle,
              ),
              child: done && !isCurrent
                  ? Icon(Icons.check,
                      size: 16.sp, color: AppColors.primaryColor)
                  : Icon(
                      isCurrent ? Icons.play_arrow_rounded : Icons.play_arrow,
                      size: 16.sp,
                      color: isCurrent
                          ? AppColors.appWhite
                          : AppColors.fontGrey,
                    ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. ${lesson.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5.sp,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.richBlack,
                    ),
                  ),
                  if (lesson.durationLabel != null || lesson.isPreview) ...[
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        if (lesson.durationLabel != null)
                          Text(
                            lesson.durationLabel!,
                            style: GoogleFonts.poppins(
                                fontSize: 10.5.sp, color: AppColors.fontGrey),
                          ),
                        if (lesson.isPreview) ...[
                          if (lesson.durationLabel != null) SizedBox(width: 6.w),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _userRating == 0 ? 'Rate this course' : 'Your rating',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.richBlack,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _userRating;
              return IconButton(
                onPressed: _savingRating ? null : () => _submitRating(i + 1),
                splashRadius: 22.r,
                padding: EdgeInsets.symmetric(horizontal: 2.w),
                constraints: const BoxConstraints(),
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFFFC107),
                  size: 34.sp,
                ),
              );
            }),
          ),
          if (_savingRating) ...[
            SizedBox(height: 10.h),
            SizedBox(
              width: 18.w,
              height: 18.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
