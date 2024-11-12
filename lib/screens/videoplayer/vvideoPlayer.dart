import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:video_player/video_player.dart';

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
      final courseDoc = await _firestore.collection('courses').doc(widget.courseId).get();

      if (courseDoc.exists) {
        courseData.value = courseDoc.data()!;

        final videoUrl = courseData['videoUrl'];
        _videoController = VideoPlayerController.network(videoUrl)
          ..initialize().then((_) {
            setState(() {});
          });

        final reviewsSnapshot = await _firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection('reviews')
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
      alignment: Alignment.center,
      children: [
        if (_videoController != null && _videoController!.value.isInitialized)
          GestureDetector(
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
        if (_showControls)
          Container(
            color: Colors.black45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.replay_10, color: Colors.white, size: 30),
                  onPressed: () {
                    _videoController!.seekTo(
                      _videoController!.value.position - const Duration(seconds: 10),
                    );
                  },
                ),
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
                IconButton(
                  icon: Icon(Icons.forward_10, color: Colors.white, size: 30),
                  onPressed: () {
                    _videoController!.seekTo(
                      _videoController!.value.position + const Duration(seconds: 10),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.fullscreen, color: Colors.white, size: 30),
                  onPressed: () {
                    // Handle fullscreen mode here
                  },
                ),
              ],
            ),
          ),
      ],
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
            icon: Icon(Icons.share),
            onPressed: () {
              // Handle share action here
            },
          ),
          IconButton(
            icon: Icon(Icons.favorite_border),
            onPressed: () {
              // Handle favorite action here
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
              Divider(color: Colors.grey, thickness: 0.5),
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
              reviews.isEmpty
                  ? const Text('No comments yet')
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        return Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                                child: Icon(Icons.person, color: AppColors.primaryColor),
                              ),
                              title: Text(
                                review['username'] ?? 'Anonymous',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                              ),
                              subtitle: Text(review['comment'] ?? '', style: TextStyle(fontSize: 12.sp)),
                              trailing: Icon(Icons.thumb_up, color: Colors.grey),
                            ),
                            Divider(color: Colors.grey.shade200, thickness: 0.5),
                          ],
                        );
                      },
                    ),
            ],
          ),
        );
      }),
      floatingActionButton: _videoController != null
          ? FloatingActionButton(
              backgroundColor: Colors.red,
              onPressed: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              child: Icon(
                _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
