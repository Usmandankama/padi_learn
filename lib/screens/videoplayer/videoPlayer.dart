import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padi_learn/utils/colors.dart';

class VideoPlayerPage extends StatefulWidget {
  final String courseId;
  const VideoPlayerPage({Key? key, required this.courseId}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  var courseData = {}.obs;
  var isLoading = true.obs;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    fetchCourseData();
  }

  @override
  void dispose() {
    _saveProgress();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> fetchCourseData() async {
    try {
      final courseDoc = await _firestore.collection('courses').doc(widget.courseId).get();
      if (courseDoc.exists) {
        courseData.value = courseDoc.data()!;
        final videoUrl = courseData['videoUrl'] ?? '';

        if (videoUrl.isNotEmpty) {
          _videoController = VideoPlayerController.network(videoUrl);
          await _videoController!.initialize();

          // Load last saved progress
          final prefs = await SharedPreferences.getInstance();
          final seconds = prefs.getInt('progress_${widget.courseId}') ?? 0;
          _videoController!.seekTo(Duration(seconds: seconds));

          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: false,
            looping: false,
            showControlsOnInitialize: true,
            allowPlaybackSpeedChanging: true,
            playbackSpeeds: [0.5, 1.0, 1.5, 2.0],
            aspectRatio: _videoController!.value.aspectRatio,
            allowFullScreen: true,
            deviceOrientationsAfterFullScreen: [
              DeviceOrientation.portraitUp,
            ],
          );

          // Track position changes
          _videoController!.addListener(() async {
            final position = _videoController!.value.position.inSeconds;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('progress_${widget.courseId}', position);
          });

          setState(() {});
        }
      }
    } catch (e) {
      print("Error fetching course or video: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _saveProgress() async {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final prefs = await SharedPreferences.getInstance();
      final seconds = _videoController!.value.position.inSeconds;
      await prefs.setInt('progress_${widget.courseId}', seconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(courseData['title'] ?? 'Course Video'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.appWhite,
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
          IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
        ],
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // VIDEO
              if (_chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: _chewieController!.aspectRatio ?? 16 / 9,
                    child: Chewie(controller: _chewieController!),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),

              SizedBox(height: 20.h),
              Text(
                "Description",
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                courseData['description'] ?? 'No description available',
                style: TextStyle(fontSize: 16.sp, color: AppColors.fontGrey),
              ),
            ],
          ),
        );
      }),
    );
  }
}
