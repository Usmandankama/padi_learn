import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:padi_learn/utils/colors.dart';

class VideoPlayerPage extends StatefulWidget {
  final String courseId;
  const VideoPlayerPage({Key? key, required this.courseId}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  final _firestore = FirebaseFirestore.instance;
  final _courseData = {}.obs;
  final _isLoading = true.obs;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  bool _showControls = false;
  bool _isBuffering = false;
  Duration? _resumePosition;

  @override
  void initState() {
    super.initState();
    _loadVideoData();
  }

  @override
  void dispose() {
    _saveProgress();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVideoData() async {
    final doc = await _firestore.collection('courses').doc(widget.courseId).get();
    if (doc.exists) {
      _courseData.value = doc.data()!;
      _resumePosition = await _getSavedPosition();

      _controller = VideoPlayerController.network(_courseData['videoUrl'])
        ..addListener(_handleListener)
        ..initialize().then((_) {
          if (_resumePosition != null) _controller!.seekTo(_resumePosition!);
          setState(() {});
        });
    }
    _isLoading.value = false;
  }

  void _handleListener() {
    setState(() {
      _isBuffering = _controller!.value.isBuffering;
    });
  }

  Future<void> _saveProgress() async {
    if (_controller != null) {
      final prefs = await SharedPreferences.getInstance();
      final current = _controller!.value.position.inSeconds;
      final duration = _controller!.value.duration.inSeconds;
      final percent = (current / duration * 100).clamp(0, 100).round();

      await prefs.setInt('pos_${widget.courseId}', current);
      await _firestore.collection('progress').doc(widget.courseId).set({
        'lastPosition': current,
        'percent': percent,
        'timestamp': DateTime.now(),
      });
    }
  }

  Future<Duration?> _getSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt('pos_${widget.courseId}') ?? 0;
    return Duration(seconds: seconds);
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        title: Text(_courseData['title'] ?? 'Video'),
        actions: [
          IconButton(icon: Icon(Icons.share), onPressed: () {}),
          IconButton(icon: Icon(Icons.favorite_border), onPressed: () {}),
        ],
      ),
      body: Obx(() {
        if (_isLoading.value) return Center(child: CircularProgressIndicator());

        return Column(
          children: [
            AspectRatio(
              aspectRatio: _controller?.value.aspectRatio ?? 16 / 9,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  VideoPlayer(_controller!),
                  if (_isBuffering) CircularProgressIndicator(),
                  if (_showControls) _buildControls(),
                  GestureDetector(
                    onTap: () {
                      setState(() => _showControls = !_showControls);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Description',
              style: TextStyle(color: AppColors.primaryColor, fontSize: 24.sp),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _courseData['description'] ?? '',
                style: TextStyle(color: AppColors.fontGrey, fontSize: 16.sp),
              ),
            )
          ],
        );
      }),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black54,
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: () {
              setState(() => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play());
              _saveProgress();
            },
          ),
          Expanded(
            child: Slider(
              value: _controller!.value.position.inSeconds.toDouble(),
              max: _controller!.value.duration.inSeconds.toDouble(),
              onChanged: (val) {
                _controller!.seekTo(Duration(seconds: val.toInt()));
              },
            ),
          ),
          DropdownButton<double>(
            dropdownColor: Colors.black,
            underline: SizedBox(),
            value: _playbackSpeed,
            onChanged: (speed) {
              setState(() {
                _playbackSpeed = speed!;
                _controller!.setPlaybackSpeed(_playbackSpeed);
              });
            },
            items: [0.5, 1.0, 1.5, 2.0].map((speed) => DropdownMenuItem(
              value: speed,
              child: Text('${speed}x', style: TextStyle(color: Colors.white)),
            )).toList(),
          ),
          IconButton(
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
            onPressed: _toggleFullscreen,
          ),
        ],
      ),
    );
  }
}
