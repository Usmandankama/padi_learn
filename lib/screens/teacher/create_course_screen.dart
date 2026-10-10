import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:padi_learn/screens/teacher/components/category_picker.dart';
import 'package:padi_learn/screens/teacher/components/course_submit_buttons.dart';
import 'package:padi_learn/screens/teacher/components/earnings_hint.dart';
import 'package:padi_learn/screens/teacher/components/paid_course_gate.dart';
import 'package:padi_learn/screens/teacher/components/upload_progress_card.dart';
import 'package:padi_learn/screens/teacher/course_detail_screen.dart';
import 'package:padi_learn/services/course_service.dart';
import 'package:padi_learn/services/lesson_service.dart';
import 'package:padi_learn/services/picked_file/picked_file.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/services/supabase_storage_service.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/utils/video_metadata.dart';

/// Creates a course and its first lesson.
///
/// A course is a series of lessons, so this screen deliberately frames the
/// video as *lesson one* rather than "the course video" — and says so — then
/// drops the teacher on the course's Lessons tab to add the rest.
///
/// It ends in two buttons. "Upload" needs the whole form and puts the course
/// in the marketplace. "Save to drafts" needs only a title and keeps whatever
/// else is filled in where only the teacher can see it, to be finished from
/// the course's own screen. A draft still sends its files now: it has to
/// outlast closing the app, and a browser cannot hold on to a picked file
/// between visits.
class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();

  /// So "Save to drafts" can ask for the title alone, without lighting up
  /// every other field's error.
  final _titleKey = GlobalKey<FormFieldState<String>>();

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _author = TextEditingController();
  final _lessonTitle = TextEditingController(text: 'Lesson 1');
  String? _category;

  XFile? _video;
  XFile? _thumbnail;
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

    final bytes = await picked.length();
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
      _video = picked;
      _videoBytes = bytes;
      _readingVideo = true;
    });

    // Captured before upload so the curriculum can show a runtime.
    final duration = await readVideoDurationSeconds(picked);
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

    final bytes = await picked.length();
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
      _thumbnail = picked;
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

  /// Whether the teacher already holds as many drafts as they may.
  ///
  /// Asked before the upload for the same reason as the bank account: the
  /// database refuses a draft over the limit, and a video can take minutes to
  /// send first. If the count cannot be read the save goes ahead and the
  /// database decides.
  Future<bool> _draftLimitReached(String userId) async {
    try {
      return await CourseService.draftCount(userId) >= kMaxCourseDrafts;
    } catch (_) {
      return false;
    }
  }

  void _openCourse(String courseId) {
    // Land on the course itself, where lesson two is one tap away — rather
    // than dropping them back on a list with no obvious next step.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CourseDetailScreen(courseId: courseId),
      ),
    );
  }

  /// Both buttons end here. [asDraft] is the only difference between them:
  /// what has to be filled in first, and whether anyone else can see the
  /// result.
  Future<void> _submit({required bool asDraft}) async {
    if (asDraft) {
      // Asked of the text itself, not of the field: the buttons are a long
      // scroll below the title, and a check that needs the field on screen
      // is a check that can silently not happen.
      if (_title.text.trim().isEmpty) {
        _titleKey.currentState?.validate();
        final field = _titleKey.currentContext;
        if (field != null) {
          Scrollable.ensureVisible(field,
              duration: const Duration(milliseconds: 250), alignment: 0.1);
        }
        _notify('Give the course a title before saving it to drafts.',
            isError: true);
        return;
      }
    } else {
      if (!_formKey.currentState!.validate()) {
        // The field at fault may be a screen or two above the button.
        _notify('Some details are missing. Check the fields marked in red.',
            isError: true);
        return;
      }

      if (_video == null || _thumbnail == null) {
        _notify('Please add a cover image and a video for the first lesson.',
            isError: true);
        return;
      }
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _notify('Your session expired. Please sign in again.', isError: true);
      return;
    }

    // A draft keeps an empty price empty; "free" is a choice, and its teacher
    // has not made it yet.
    final priceText = _price.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);

    if (asDraft) {
      if (await _draftLimitReached(userId)) {
        _notify(kDraftLimitMessage, isError: true);
        return;
      }
    } else if ((price ?? 0) > 0 && !await ensureCanSellPaid(context)) {
      // Before the upload, not after: a paid course needs a bank account, and
      // the video can take minutes to send. A draft is asked when it is
      // uploaded instead.
      return;
    }
    if (!mounted) return;

    setState(() {
      _saving = true;
      _progress = null;
    });

    MediaUploadResult? upload;
    String? courseId;
    try {
      upload = await uploadCourseMedia(
        userId: userId,
        videoFile: _video,
        thumbnailFile: _thumbnail,
        onProgress: _onProgress,
      );
      if (!upload.success) {
        _notify(upload.error ?? 'Media upload failed', isError: true);
        return;
      }
      // A draft with no files sends nothing, so nothing has moved the card on
      // from "Preparing upload".
      if (_video == null && _thumbnail == null && mounted) {
        setState(() => _progress = const UploadProgress(
              stage: UploadStage.saving,
              bytesSent: 0,
              totalBytes: 0,
              elapsed: Duration.zero,
            ));
      }

      courseId = await CourseService.create(
        userId: userId,
        title: _title.text,
        description: _description.text,
        price: asDraft ? price : price ?? 0,
        category: _category,
        author: _author.text,
        thumbnailUrl: upload.thumbnailUrl,
        asDraft: asDraft,
      );

      // A lesson is its video, so a draft saved without one has no lesson
      // yet; it is added from the course's Lessons tab.
      if (upload.videoPath != null) {
        await LessonService.add(
          courseId: courseId,
          title: _lessonTitle.text.trim().isEmpty
              ? 'Lesson 1'
              : _lessonTitle.text.trim(),
          videoPath: upload.videoPath!,
          durationSeconds: _videoDuration,
          isPreview: _firstLessonIsPreview,
        );
      }

      if (!mounted) return;
      _openCourse(courseId);
      _notify(!asDraft
          ? 'Your course is live. Add more lessons whenever you are ready.'
          : upload.videoPath == null
              ? 'Saved to drafts, without a lesson yet. Only you can see it '
                  'until you upload it.'
              : 'Saved to drafts. Only you can see it until you upload it.');
    } catch (e) {
      // Only when the database itself said no is it certain that nothing
      // points at the files just sent, and safe to take them back out. After
      // a dropped connection the row may well have been written.
      final refused = e is PostgrestException;

      if (courseId == null) {
        if (refused) {
          await removeStoredObject(upload?.videoPath,
              fallbackBucket: kCourseMediaBucket);
          await removeStoredObject(upload?.thumbnailUrl,
              fallbackBucket: kCourseThumbnailBucket);
        }
        _notify(
          courseErrorMessage(e,
              fallback: asDraft
                  ? 'Could not save the draft'
                  : 'Failed to create course'),
          isError: true,
        );
      } else {
        // The course is saved and only its first lesson is not. Staying on
        // this form would invite a second copy of the course.
        if (refused) {
          await removeStoredObject(upload?.videoPath,
              fallbackBucket: kCourseMediaBucket);
        }
        if (mounted) _openCourse(courseId);
        _notify(
          'The course was saved, but its first lesson was not. Add it from '
          'the Lessons tab.',
          isError: true,
        );
      }
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
        iconTheme: IconThemeData(color: AppColors.palette.ink),
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
        // Not a ListView: that builds lazily and throws away the fields that
        // scroll out of view, and a Form can only validate the fields it
        // still has. With the button at the bottom, that was most of them.
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(
                title: 'Course details',
                children: [
                  _field(
                    fieldKey: _titleKey,
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
                    decoration:
                        _decoration('Category', Icons.category_outlined),
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
                CourseSubmitButtons(
                  // Null (not an empty callback) so the buttons actually grey
                  // out while the duration probe runs.
                  onSaveDraft:
                      _readingVideo ? null : () => _submit(asDraft: true),
                  onUpload:
                      _readingVideo ? null : () => _submit(asDraft: false),
                ),
            ],
          ),
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
                ? Image(
                    image: pickedImageProvider(_thumbnail!),
                    fit: BoxFit.cover,
                  )
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
                              fontSize: 11.5.sp,
                              color: AppColors.palette.inkSoft),
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
                    fontSize: 11.sp, color: AppColors.palette.inkSoft),
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
            color: AppColors.palette.ground,
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
                      : '${_video!.name} '
                          '(${formatBytes(_videoBytes)})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: _video == null
                        ? AppColors.palette.inkSoft
                        : AppColors.palette.ink,
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
                    fontSize: 11.5.sp, color: AppColors.palette.inkSoft),
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
                  color: AppColors.palette.ink,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Let anyone watch this lesson before buying. The most reliable '
                'way to sell a paid course.',
                style: GoogleFonts.poppins(
                    fontSize: 11.sp, color: AppColors.palette.inkSoft),
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
        color: AppColors.palette.surface,
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
              color: AppColors.palette.ink,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 11.5.sp, color: AppColors.palette.inkSoft),
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
      labelStyle: GoogleFonts.poppins(
          fontSize: 13.sp, color: AppColors.palette.inkSoft),
      prefixIcon: Icon(icon, size: 20.sp, color: AppColors.primaryColor),
      filled: true,
      fillColor: AppColors.palette.ground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _field({
    Key? fieldKey,
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
      key: fieldKey,
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
