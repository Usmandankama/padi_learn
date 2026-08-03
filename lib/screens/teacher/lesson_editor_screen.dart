import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/teacher/components/upload_progress_card.dart';
import 'package:padi_learn/services/lesson_service.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/services/supabase_storage_service.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/video_metadata.dart';

/// Adds a lesson to a course, or edits an existing one.
///
/// Pops `true` when something was saved.
class LessonEditorScreen extends StatefulWidget {
  final String courseId;

  /// Null when adding.
  final Lesson? lesson;

  const LessonEditorScreen({
    super.key,
    required this.courseId,
    this.lesson,
  });

  bool get isEditing => lesson != null;

  @override
  State<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends State<LessonEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;

  File? _video;
  int _videoBytes = 0;
  int? _videoDuration;
  bool _readingVideo = false;

  late bool _isPreview;
  bool _saving = false;
  UploadProgress? _progress;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.lesson?.title ?? '');
    _isPreview = widget.lesson?.isPreview ?? false;
    _videoDuration = widget.lesson?.durationSeconds;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.length();
    if (bytes > kMaxVideoBytes) {
      _notify(
        'That video is ${formatBytes(bytes)}. The limit is '
        '${formatBytes(kMaxVideoBytes)} — please trim or compress it.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _video = file;
      _videoBytes = bytes;
      _readingVideo = true;
    });

    final duration = await readVideoDurationSeconds(file);
    if (!mounted) return;
    setState(() {
      _videoDuration = duration;
      _readingVideo = false;
    });
  }

  void _onProgress(UploadProgress progress) {
    if (!mounted) return;
    final previous = _progress;
    final changed = previous == null ||
        previous.stage != progress.stage ||
        previous.percent != progress.percent;
    if (!changed) return;
    setState(() => _progress = progress);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // A new lesson has to come with a video; an edit may keep the existing one.
    if (!widget.isEditing && _video == null) {
      _notify('Please choose a video for this lesson.', isError: true);
      return;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _notify('Your session expired. Please sign in again.', isError: true);
      return;
    }

    setState(() {
      _saving = true;
      _progress = null;
    });

    final previousVideo = widget.lesson?.videoPath;

    try {
      String? uploadedPath;
      if (_video != null) {
        final upload = await uploadCourseMedia(
          userId: userId,
          videoFile: _video,
          onProgress: _onProgress,
        );
        if (!upload.success) {
          _notify(upload.error ?? 'Upload failed', isError: true);
          return;
        }
        uploadedPath = upload.videoPath;
      }

      if (widget.isEditing) {
        await LessonService.update(
          lessonId: widget.lesson!.id,
          title: _title.text.trim(),
          videoPath: uploadedPath,
          durationSeconds: _videoDuration,
          isPreview: _isPreview,
        );
        // The row points at the new file now, so the old one can go.
        if (uploadedPath != null) {
          await removeStoredObject(previousVideo,
              fallbackBucket: kCourseMediaBucket);
        }
      } else {
        await LessonService.add(
          courseId: widget.courseId,
          title: _title.text.trim(),
          videoPath: uploadedPath!,
          durationSeconds: _videoDuration,
          isPreview: _isPreview,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      _notify(widget.isEditing ? 'Lesson updated.' : 'Lesson added.');
    } catch (e) {
      _notify('Could not save the lesson: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
      }
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.richBlack),
        title: Text(
          widget.isEditing ? 'Edit Lesson' : 'Add Lesson',
          style: GoogleFonts.poppins(
            color: AppColors.primaryColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
          children: [
            _card(
              child: TextFormField(
                controller: _title,
                enabled: !_saving,
                style: GoogleFonts.poppins(fontSize: 13.sp),
                decoration: InputDecoration(
                  labelText: 'Lesson title',
                  labelStyle: GoogleFonts.poppins(
                      fontSize: 13.sp, color: AppColors.fontGrey),
                  prefixIcon: Icon(Icons.title,
                      size: 20.sp, color: AppColors.primaryColor),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please give this lesson a title'
                    : null,
              ),
            ),
            SizedBox(height: 14.h),
            _card(child: _videoPicker()),
            SizedBox(height: 14.h),
            _card(child: _previewToggle()),
            SizedBox(height: 24.h),
            if (_saving)
              UploadProgressCard(progress: _progress)
            else
              PrimaryButton(
                label: widget.isEditing ? 'Save lesson' : 'Add lesson',
                isLoading: false,
                // Null (not an empty callback) so the button actually greys
                // out while the duration probe runs.
                onPressed: _readingVideo ? null : _save,
              ),
          ],
        ),
      ),
    );
  }

  Widget _videoPicker() {
    final hasExisting = widget.lesson?.hasVideo == true;
    final durationLabel = _videoDuration == null
        ? null
        : Lesson(
            id: '',
            courseId: '',
            title: '',
            position: 1,
            videoPath: null,
            durationSeconds: _videoDuration,
            isPreview: false,
          ).durationLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Video',
          style: GoogleFonts.poppins(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.richBlack,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(Icons.movie_outlined,
                  size: 22.sp, color: AppColors.primaryColor),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  _video != null
                      ? '${_video!.path.split(RegExp(r"[\\/]")).last} '
                          '(${formatBytes(_videoBytes)})'
                      : hasExisting
                          ? 'Current video will be kept'
                          : 'No video chosen yet',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: _video != null
                        ? AppColors.richBlack
                        : AppColors.fontGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            TextButton.icon(
              onPressed: _saving ? null : _pickVideo,
              icon: Icon(Icons.upload_outlined,
                  size: 18.sp, color: AppColors.primaryColor),
              label: Text(
                hasExisting || _video != null ? 'Replace video' : 'Choose video',
                style: GoogleFonts.poppins(
                    fontSize: 12.5.sp, color: AppColors.primaryColor),
              ),
            ),
            const Spacer(),
            if (_readingVideo)
              SizedBox(
                width: 14.w,
                height: 14.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else if (durationLabel != null)
              Text(
                durationLabel,
                style: GoogleFonts.poppins(
                    fontSize: 11.5.sp, color: AppColors.fontGrey),
              ),
          ],
        ),
      ],
    );
  }

  Widget _previewToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Free preview',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.richBlack,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Anyone can watch this lesson without buying the course. '
                'A good hook for lesson one.',
                style: GoogleFonts.poppins(
                    fontSize: 11.sp, color: AppColors.fontGrey),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: _isPreview,
          activeThumbColor: AppColors.primaryColor,
          onChanged: _saving ? null : (v) => setState(() => _isPreview = v),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
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
      child: child,
    );
  }
}
