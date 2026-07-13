import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/videoplayer/components/comments_section.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/utils/colors.dart';

class VideoPlayerPage extends StatefulWidget {
  final String courseId;
  const VideoPlayerPage({super.key, required this.courseId});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  SharedPreferences? _prefs;

  Map<String, dynamic> _course = {};
  bool _loading = true;

  int _userRating = 0;
  double _avgRating = 0;
  int _ratingCount = 0;
  bool _savingRating = false;

  // Throttle: only persist progress when the whole-second value changes and is
  // a multiple of 5 — avoids the per-frame disk writes that caused stutter.
  int _lastSavedSeconds = -1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onTick);
    _saveProgress();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCourse();
    await _loadRatings();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCourse() async {
    try {
      final data = await supabase
          .from('courses')
          .select()
          .eq('id', widget.courseId)
          .maybeSingle();
      if (data == null) return;
      _course = data;

      final videoUrl = (data['video_url'] ?? '').toString();
      if (videoUrl.isEmpty) return;

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoController = controller;
      await controller.initialize();

      // Resume from the last saved position.
      final saved = _prefs?.getInt('progress_${widget.courseId}') ?? 0;
      if (saved > 0 && saved < controller.value.duration.inSeconds) {
        await controller.seekTo(Duration(seconds: saved));
      }

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
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
    } catch (e) {
      debugPrint('Error loading course video: $e');
    }
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

  void _onTick() {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;
    final seconds = c.value.position.inSeconds;
    if (seconds != _lastSavedSeconds && seconds % 5 == 0) {
      _lastSavedSeconds = seconds;
      _prefs?.setInt('progress_${widget.courseId}', seconds);
    }
  }

  Future<void> _saveProgress() async {
    final c = _videoController;
    if (c == null || !c.value.isInitialized) return;

    final position = c.value.position;
    final duration = c.value.duration;
    _prefs?.setInt('progress_${widget.courseId}', position.inSeconds);

    final uid = supabase.auth.currentUser?.id;
    if (uid != null && duration.inSeconds > 0) {
      final percent =
          ((position.inSeconds / duration.inSeconds) * 100).clamp(0, 100).round();
      try {
        await supabase
            .from('enrollments')
            .update({'progress': percent})
            .eq('user_id', uid)
            .eq('course_id', widget.courseId);
      } catch (_) {
        // Local progress is still saved.
      }
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

      // Re-read the freshly recomputed aggregate.
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

  @override
  Widget build(BuildContext context) {
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
                          (_course['title'] ?? 'Course').toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.richBlack,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 16.sp, color: AppColors.fontGrey),
                            SizedBox(width: 4.w),
                            Text(
                              'By ${(_course['author'] ?? 'Unknown')}',
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: AppColors.fontGrey,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.star_rounded,
                                size: 16.sp, color: const Color(0xFFFFC107)),
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
                        ),
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

  Widget _buildVideo() {
    final ready = _chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized;
    return AspectRatio(
      aspectRatio: ready ? _videoController!.value.aspectRatio : 16 / 9,
      child: ready
          ? Chewie(controller: _chewieController!)
          : Container(
              color: Colors.black,
              child: const AppLoader(),
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
