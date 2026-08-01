import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:padi_learn/screens/components/primary_button.dart';
import 'package:padi_learn/screens/teacher/components/upload_progress_card.dart';
import 'package:padi_learn/services/course_service.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/services/supabase_storage_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Edits an existing course: details, pricing and both media files.
///
/// Pops `true` when something was saved, so the caller can refresh.
///
/// Taking a course off the marketplace lives on the course detail screen rather
/// than here — it needs the explanation about enrolled students keeping access,
/// and one home for that decision is less confusing than two.
class EditCourseScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const EditCourseScreen({
    super.key,
    required this.courseId,
    required this.courseData,
  });

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _author;
  String? _category;

  /// Newly picked replacements. Null means "keep what is already there".
  File? _newVideo;
  File? _newThumbnail;
  int _newVideoBytes = 0;
  int _newThumbnailBytes = 0;

  bool _saving = false;
  UploadProgress? _progress;

  static const List<String> _categories = [
    'Programming',
    'Design',
    'Marketing',
    'Business',
    'Data Science',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.courseData;
    _title = TextEditingController(text: (data['title'] ?? '').toString());
    _description =
        TextEditingController(text: (data['description'] ?? '').toString());
    _price = TextEditingController(
        text: ((data['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));
    _author = TextEditingController(text: (data['author'] ?? '').toString());

    final category = (data['category'] ?? '').toString();
    _category = _categories.contains(category) ? category : null;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _author.dispose();
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
      _newVideo = file;
      _newVideoBytes = bytes;
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
      _newThumbnail = file;
      _newThumbnailBytes = bytes;
    });
  }

  /// Throttled so a large replacement repaints once per percent.
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _notify('Your session expired. Please sign in again.', isError: true);
      return;
    }

    setState(() {
      _saving = true;
      _progress = null;
    });

    final previousVideo = widget.courseData['video_url'] as String?;
    final previousThumbnail = widget.courseData['thumbnail_url'] as String?;

    try {
      // Uploads only run for files the teacher actually replaced.
      final upload = await uploadCourseMedia(
        userId: userId,
        videoFile: _newVideo,
        thumbnailFile: _newThumbnail,
        onProgress: _onProgress,
      );
      if (!upload.success) {
        _notify(upload.error ?? 'Upload failed', isError: true);
        return;
      }

      await CourseService.updateDetails(
        courseId: widget.courseId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        price: double.tryParse(_price.text.trim()) ?? 0,
        category: _category,
        author: _author.text.trim(),
        videoPath: upload.videoPath,
        thumbnailUrl: upload.thumbnailUrl,
      );

      // The row now points at the new files, so the old ones are safe to drop.
      if (upload.videoPath != null) {
        await removeStoredObject(previousVideo,
            fallbackBucket: kCourseMediaBucket);
      }
      if (upload.thumbnailUrl != null) {
        await removeStoredObject(previousThumbnail,
            fallbackBucket: kCourseThumbnailBucket);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      _notify('Course updated.');
    } catch (e) {
      _notify('Could not save your changes: $e', isError: true);
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
          'Edit Course',
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
                  label: 'Title',
                  icon: Icons.title,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a course title'
                      : null,
                ),
                SizedBox(height: 14.h),
                _field(
                  controller: _description,
                  label: 'Description',
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
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: _decoration('Category', Icons.category_outlined),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) => setState(() => _category = value),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Please pick a category' : null,
                ),
                SizedBox(height: 14.h),
                _field(
                  controller: _price,
                  label: 'Price (NGN) — 0 makes it free',
                  icon: Icons.sell_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter a price';
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _section(
              title: 'Media',
              children: [
                _thumbnailPicker(),
                SizedBox(height: 16.h),
                _videoPicker(),
              ],
            ),
            SizedBox(height: 24.h),
            if (_saving)
              UploadProgressCard(progress: _progress)
            else
              PrimaryButton(
                label: 'Save changes',
                isLoading: false,
                onPressed: _save,
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailPicker() {
    final currentUrl = (widget.courseData['thumbnail_url'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cover image',
          style: GoogleFonts.poppins(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.richBlack,
          ),
        ),
        SizedBox(height: 8.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _newThumbnail != null
                ? Image.file(_newThumbnail!, fit: BoxFit.cover)
                : currentUrl.isEmpty
                    ? Container(color: AppColors.primaryAccent)
                    : Image.network(
                        currentUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.primaryAccent,
                          child: Icon(Icons.image_not_supported,
                              color: AppColors.fontGrey, size: 26.sp),
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
                _newThumbnail == null ? 'Replace image' : 'Choose another',
                style: GoogleFonts.poppins(
                    fontSize: 12.5.sp, color: AppColors.primaryColor),
              ),
            ),
            if (_newThumbnail != null)
              Expanded(
                child: Text(
                  'New · ${formatBytes(_newThumbnailBytes)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
                      fontSize: 11.sp, color: AppColors.fontGrey),
                ),
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
        Text(
          'Lesson video',
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
                  _newVideo == null
                      ? 'Current video will be kept'
                      : '${_newVideo!.path.split(RegExp(r"[\\/]")).last} '
                          '(${formatBytes(_newVideoBytes)})',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: _newVideo == null
                        ? AppColors.fontGrey
                        : AppColors.richBlack,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        TextButton.icon(
          onPressed: _saving ? null : _pickVideo,
          icon: Icon(Icons.upload_outlined,
              size: 18.sp, color: AppColors.primaryColor),
          label: Text(
            _newVideo == null ? 'Replace video' : 'Choose another',
            style: GoogleFonts.poppins(
                fontSize: 12.5.sp, color: AppColors.primaryColor),
          ),
        ),
        if (_newVideo != null)
          Text(
            'Students who already bought this course will see the new video.',
            style: GoogleFonts.poppins(
                fontSize: 11.sp, color: AppColors.fontGrey),
          ),
      ],
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      enabled: !_saving,
      style: GoogleFonts.poppins(fontSize: 13.sp),
      decoration: _decoration(label, icon),
      validator: validator,
    );
  }
}
