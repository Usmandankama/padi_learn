import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:padi_learn/utils/colors.dart';

class VideoPlayerPage extends StatefulWidget {
  final String courseId;

  const VideoPlayerPage({Key? key, required this.courseId}) : super(key: key);

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _videoController;
  var courseData = {}.obs;
  var reviews = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  bool _showControls = false;
  bool _isBuffering = false;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;


  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    fetchCourseDetails();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void fetchCourseDetails() async {
    try {
      final courseDoc =
          await _firestore.collection('courses').doc(widget.courseId).get();

      if (courseDoc.exists) {
        courseData.value = courseDoc.data()!;

        final videoUrl = courseData['videoUrl'] ?? '';
        if (videoUrl.isNotEmpty) {
          _videoController = VideoPlayerController.network(videoUrl)
            ..addListener(() {
              setState(() {
                _isBuffering = _videoController!.value.isBuffering;
              });
            })
            ..initialize().then((_) {
              setState(() {});
            }).catchError((error) {
              print('Error initializing video: $error');
            });
        }

        final reviewsSnapshot = await _firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection('reviews')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();

        reviews.value = reviewsSnapshot.docs.map((doc) => doc.data()).toList();
      }
    } catch (e) {
      print('Error fetching course details: $e');
    } finally {
      isLoading.value = false;
    }
  }

Widget _buildVideoPlayer() {
  return Stack(
    alignment: Alignment.bottomCenter,
    children: [
      if (_videoController != null && _videoController!.value.isInitialized)
        GestureDetector(
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
            if (_showControls) {
              Future.delayed(const Duration(seconds: 3), () {
                setState(() {
                  _showControls = false;
                });
              });
            }
          },
          onDoubleTapDown: (details) {
            final tapPosition = details.localPosition.dx;
            final screenWidth = MediaQuery.of(context).size.width;

            if (tapPosition < screenWidth / 2) {
              _videoController!.seekTo(
                _videoController!.value.position - const Duration(seconds: 10),
              );
            } else {
              _videoController!.seekTo(
                _videoController!.value.position + const Duration(seconds: 10),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 3.5 / 2.5,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
      if (_isBuffering) const Center(child: CircularProgressIndicator()),
      if (_showControls)
        _buildControls(),
    ],
  );
}

Widget _buildControls() {
  return Align(
    alignment: Alignment.bottomCenter,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black26.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _videoController!.value.isPlaying
                        ? _videoController!.pause()
                        : _videoController!.play();
                  });
                },
              ),
              Expanded(
                child: Slider(
                  value: _videoController!.value.position.inSeconds.toDouble(),
                  max: _videoController!.value.duration.inSeconds.toDouble(),
                  onChanged: (value) {
                    _videoController!.seekTo(Duration(seconds: value.toInt()));
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 30),
                onPressed: () {
                  if (_isFullscreen) {
                    _exitFullscreenMode();
                  } else {
                    _enterFullscreenMode();
                  }
                },
              ),
              DropdownButton<double>(
                dropdownColor: Colors.black,
                value: _playbackSpeed,
                onChanged: (value) {
                  setState(() {
                    _playbackSpeed = value!;
                    _videoController!.setPlaybackSpeed(_playbackSpeed);
                  });
                },
                items: [0.5, 1.0, 1.5, 2.0]
                    .map((speed) => DropdownMenuItem(
                          value: speed,
                          child: Text(
                            '${speed}x',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _enterFullscreenMode() {
  _isFullscreen = true;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: StatefulBuilder(
          builder: (fullscreenContext, setFullscreenState) {
            void toggleControls() {
              setFullscreenState(() {
                _showControls = !_showControls;
              });
              if (_showControls) {
                Future.delayed(const Duration(seconds: 3), () {
                  setFullscreenState(() {
                    _showControls = false;
                  });
                });
              }
            }

            return GestureDetector(
              onTap: toggleControls,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Center(
                    child: VideoPlayer(_videoController!),
                  ),
                  if (_showControls)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _videoController!.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  onPressed: () {
                                    setFullscreenState(() {
                                      _videoController!.value.isPlaying
                                          ? _videoController!.pause()
                                          : _videoController!.play();
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _videoController!.value.position.inSeconds.toDouble(),
                                    max: _videoController!.value.duration.inSeconds.toDouble(),
                                    onChanged: (value) {
                                      _videoController!.seekTo(Duration(seconds: value.toInt()));
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.fullscreen_exit,
                                      color: Colors.white, size: 30),
                                  onPressed: () {
                                    _exitFullscreenMode();
                                  },
                                ),
                                DropdownButton<double>(
                                  dropdownColor: Colors.black,
                                  value: _playbackSpeed,
                                  onChanged: (value) {
                                    setFullscreenState(() {
                                      _playbackSpeed = value!;
                                      _videoController!.setPlaybackSpeed(_playbackSpeed);
                                    });
                                  },
                                  items: [0.5, 1.0, 1.5, 2.0]
                                      .map((speed) => DropdownMenuItem(
                                            value: speed,
                                            child: Text(
                                              '${speed}x',
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}
void _exitFullscreenMode() {
  _isFullscreen = false;
  Navigator.pop(context);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}


  Widget _buildCommentList() {
    return reviews.isEmpty
        ? const Text('No comments yet')
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                      child: const Icon(Icons.person,
                          color: AppColors.primaryColor),
                    ),
                    title: Text(
                      review['username'] ?? 'Anonymous',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14.sp),
                    ),
                    subtitle: Text(review['comment'] ?? '',
                        style: TextStyle(fontSize: 12.sp)),
                    trailing: IconButton(
                      icon: const Icon(Icons.thumb_up, color: Colors.grey),
                      onPressed: () {
                        // Increment like count in Firestore
                      },
                    ),
                  ),
                  Divider(color: Colors.grey.shade200, thickness: 0.5),
                ],
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(courseData['title'] ?? 'Course Details'),
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Handle share action
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              // Handle favorite action
            },
          ),
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
              _buildVideoPlayer(),
              SizedBox(height: 10.h),
              Text(
                courseData['description'] ?? 'No description available',
                style: TextStyle(
                  color: AppColors.fontGrey,
                  fontSize: 16.sp,
                ),
              ),
              const Divider(color: Colors.grey, thickness: 0.5),
              SizedBox(height: 10.h),
              Text(
                'Comments',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10.h),
              _buildCommentList(),
            ],
          ),
        );
      }),
    );
  }
}
