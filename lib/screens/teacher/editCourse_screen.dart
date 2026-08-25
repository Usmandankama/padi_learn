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

  /// Newly picked replacement. Null means "keep the existing cover".
  File? _newThumbnail;
  int _newThumbnailBytes = 0;

  bool _saving = false;
  UploadProgress? _progress;

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

    // Kept as-is even if it is no longer an approved category — the picker
    // folds an unrecognised current value into its list rather than dropping
    // it, so editing a course can't silently clear its category.
    final category = (data['category'] ?? '').toString();
    _category = category.isEmpty ? null : category;
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

    final previousThumbnail = widget.courseData['thumbnail_url'] as String?;

    try {
      // Only runs when the teacher actually picked a new cover.
      final upload = await uploadCourseMedia(
        userId: userId,
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
        thumbnailUrl: upload.thumbnailUrl,
      );

      // The row now points at the new file, so the old one is safe to drop.
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
                CategoryPicker(
                  value: _category,
                  enabled: !_saving,
                  decoration: _decoration('Category', Icons.category_outlined),
                  onChanged: (value) => setState(() => _category = value),
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
              children: [
                _thumbnailPicker(),
                SizedBox(height: 12.h),
                // Videos belong to lessons now, so they are edited there
                // rather than here.
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 15.sp, color: AppColors.fontGrey),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        'Lesson videos are managed in the Lessons tab.',
                        style: GoogleFonts.poppins(
                            fontSize: 11.sp, color: AppColors.fontGrey),
                      ),
                    ),
                  ],
                ),
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
