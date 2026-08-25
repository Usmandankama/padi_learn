import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/teacher/components/category_picker.dart';
import 'package:padi_learn/screens/teacher/components/earnings_hint.dart';
import 'package:padi_learn/screens/teacher/components/upload_progress_card.dart';
import 'package:padi_learn/screens/teacher/course_detail_screen.dart';
import 'package:padi_learn/services/lesson_service.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/services/supabase_storage_service.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/video_metadata.dart';

/// Creates a course and its first lesson.
///
/// A course is a series of lessons, so this screen deliberately frames the
/// video as *lesson one* rather than "the course video" — and says so — then
/// drops the teacher on the course's Lessons tab to add the rest.
class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _author = TextEditingController();
  final _lessonTitle = TextEditingController(text: 'Lesson 1');
  String? _category;

  File? _video;
  File? _thumbnail;
  int _videoBytes = 0;
  int _thumbnailBytes = 0;
  int? _videoDuration;
  bool _readingVideo = false;
  bool _firstLessonIsPreview = false;

  bool _saving = false;
  UploadProgress? _progress;

  @override
  void initState() {
    super.initState();
    _prefillAuthor();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _author.dispose();
    _lessonTitle.dispose();
    super.dispose();
  }

  /// Nobody should have to type their own name. Still editable — a teacher may
  /// publish under a brand rather than their profile name.
  Future<void> _prefillAuthor() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final profile = await supabase
          .from('profiles')
          .select('name')
          .eq('id', uid)
          .maybeSingle();
      final name = (profile?['name'] as String?)?.trim() ?? '';
      if (mounted && name.isNotEmpty && _author.text.trim().isEmpty) {
        _author.text = name;
      }
    } catch (_) {
      // Not important enough to surface — they can type it.
    }
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

  // ---------------------------------------------------------------------------
  // Media
  // ---------------------------------------------------------------------------

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

    // Captured before upload so the curriculum can show a runtime.
    final duration = await readVideoDurationSeconds(file);
    if (!mounted) return;
    setState(() {
      _videoDuration = duration;
      _readingVideo = false;
    });
  }

  Future<void> _pickThumbnail() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.length();
    if (bytes > kMaxThumbnailBytes) {
      _notify(
        'That image is ${formatBytes(bytes)}. The limit is '
        '${formatBytes(kMaxThumbnailBytes)}.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _thumbnail = file;
      _thumbnailBytes = bytes;
    });
  }

  /// Throttled so a large upload repaints once per percent.
  void _onProgress(UploadProgress progress) {
    if (!mounted) return;
    final previous = _progress;
    final changed = previous == null ||
        previous.stage != progress.stage ||
        previous.percent != progress.percent;
    if (!changed) return;
    setState(() => _progress = progress);
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    if (_video == null || _thumbnail == null) {
      _notify('Please add a cover image and a video for the first lesson.',
          isError: true);
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

    try {
      final upload = await uploadCourseMedia(
        userId: userId,
        videoFile: _video,
        thumbnailFile: _thumbnail,
        onProgress: _onProgress,
      );
      if (!upload.success) {
        _notify(upload.error ?? 'Media upload failed', isError: true);
        return;
      }

      final course = await supabase
          .from('courses')
          .insert({
            'title': _title.text.trim(),
            'description': _description.text.trim(),
            'price': double.tryParse(_price.text.trim()) ?? 0,
            'category': _category,
            'author': _author.text.trim(),
            'thumbnail_url': upload.thumbnailUrl,
            'user_id': userId,
          })
          .select('id')
          .single();

      final courseId = (course['id'] ?? '').toString();

      await LessonService.add(
        courseId: courseId,
        title: _lessonTitle.text.trim().isEmpty
            ? 'Lesson 1'
            : _lessonTitle.text.trim(),
        videoPath: upload.videoPath!,
        durationSeconds: _videoDuration,
        isPreview: _firstLessonIsPreview,
      );

      if (!mounted) return;
      // Land on the course itself, where lesson two is one tap away — rather
      // than dropping them back on a list with no obvious next step.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen(courseId: courseId),
        ),
      );
      _notify('Course created. Add more lessons whenever you are ready.');
    } catch (e) {
      _notify('Failed to create course: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

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
          'New Course',
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
            _section(
              title: 'Course details',
              children: [
                _field(
                  controller: _title,
                  label: 'Course title',
                  icon: Icons.title,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a course title'
                      : null,
                ),
                SizedBox(height: 14.h),
                _field(
                  controller: _description,
                  label: 'What will students learn?',
                  icon: Icons.notes,
                  maxLines: 5,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a description'
                      : null,
                ),
                SizedBox(height: 14.h),
                _field(
                  controller: _author,
                  label: 'Author name',
                  icon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter the author name'
                      : null,
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _section(
              title: 'Category & price',
              children: [
                CategoryPicker(
                  value: _category,
                  enabled: !_saving,
                  decoration: _decoration('Category', Icons.category_outlined),
                  onChanged: (v) => setState(() => _category = v),
                ),
                SizedBox(height: 14.h),
                _field(
                  controller: _price,
                  label: 'Price (NGN) — 0 makes it free',
                  icon: Icons.sell_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  // Rebuild so the earnings estimate tracks what they type.
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter a price';
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 10.h),
                EarningsHint(priceText: _price.text),
              ],
            ),
            SizedBox(height: 14.h),
            _section(
              title: 'Cover image',
              children: [_thumbnailPicker()],
            ),
            SizedBox(height: 14.h),
            _section(
              title: 'First lesson',
              subtitle:
                  'Courses are made of lessons. Add one to get started — you '
                  'can add the rest right after.',
              children: [
                _field(
                  controller: _lessonTitle,
                  label: 'Lesson title',
                  icon: Icons.play_lesson_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Give the first lesson a title'
                      : null,
                ),
                SizedBox(height: 14.h),
                _videoPicker(),
                SizedBox(height: 6.h),
                _previewToggle(),
              ],
            ),
            SizedBox(height: 24.h),
            if (_saving)
              UploadProgressCard(progress: _progress)
            else
              PrimaryButton(
                label: 'Create course',
                isLoading: false,
                // Null (not an empty callback) so the button actually greys
                // out while the duration probe runs.
                onPressed: _readingVideo ? null : _create,
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _thumbnail != null
                ? Image.file(_thumbnail!, fit: BoxFit.cover)
                : Container(
                    color: AppColors.primaryAccent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 30.sp, color: AppColors.primaryColor),
                        SizedBox(height: 6.h),
                        Text(
                          'No cover chosen',
                          style: GoogleFonts.poppins(
                              fontSize: 11.5.sp, color: AppColors.fontGrey),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            TextButton.icon(
              onPressed: _saving ? null : _pickThumbnail,
              icon: Icon(Icons.image_outlined,
                  size: 18.sp, color: AppColors.primaryColor),
              label: Text(
                _thumbnail == null ? 'Choose image' : 'Choose another',
                style: GoogleFonts.poppins(
                    fontSize: 12.5.sp, color: AppColors.primaryColor),
              ),
            ),
            const Spacer(),
            if (_thumbnail != null)
              Text(
                formatBytes(_thumbnailBytes),
                style: GoogleFonts.poppins(
                    fontSize: 11.sp, color: AppColors.fontGrey),
              ),
          ],
        ),
      ],
    );
  }

  Widget _videoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  _video == null
                      ? 'No video chosen yet'
                      : '${_video!.path.split(RegExp(r"[\\/]")).last} '
                          '(${formatBytes(_videoBytes)})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: _video == null
                        ? AppColors.fontGrey
                        : AppColors.richBlack,
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
                _video == null ? 'Choose video' : 'Choose another',
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
            else if (_videoDuration != null)
              Text(
                Lesson(
                  id: '',
                  courseId: '',
                  title: '',
                  position: 1,
                  videoPath: null,
                  durationSeconds: _videoDuration,
                  isPreview: false,
                ).durationLabel!,
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
                'Let anyone watch this lesson before buying. The most reliable '
                'way to sell a paid course.',
                style: GoogleFonts.poppins(
                    fontSize: 11.sp, color: AppColors.fontGrey),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: _firstLessonIsPreview,
          activeThumbColor: AppColors.primaryColor,
          onChanged:
              _saving ? null : (v) => setState(() => _firstLessonIsPreview = v),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
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
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 11.5.sp, color: AppColors.fontGrey),
            ),
          ],
          SizedBox(height: 14.h),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          GoogleFonts.poppins(fontSize: 13.sp, color: AppColors.fontGrey),
      prefixIcon: Icon(icon, size: 20.sp, color: AppColors.primaryColor),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      enabled: !_saving,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 13.sp),
      decoration: _decoration(label, icon),
      validator: validator,
    );
  }
}
