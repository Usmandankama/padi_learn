import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/services/category_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Category dropdown backed by the `categories` table, with a "suggest a new
/// one" escape hatch.
///
/// A suggestion is saved inactive, so it labels this course without appearing
/// in anyone's browse filters until it is approved.
class CategoryPicker extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final InputDecoration decoration;
  final bool enabled;

  const CategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decoration,
    this.enabled = true,
  });

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  /// Sentinel entry that opens the suggestion dialog instead of selecting.
  static const String _suggestValue = '__suggest__';

  List<Category> _categories = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await CategoryService.forPicker();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Leave the list empty; the current value is still preserved below.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Names to offer, always including the current value.
  ///
  /// A course can carry a category that is not in the fetched list — another
  /// teacher's pending suggestion, or one that was deactivated. Dropdowns
  /// assert when their value is absent from their items, so it is folded in.
  List<String> get _names {
    final names = _categories.map((c) => c.name).toList();
    final current = widget.value;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }
    return names;
  }

  bool _isPending(String name) => _categories
      .any((category) => category.name == name && !category.isActive);

  Future<void> _promptForNewCategory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Suggest a category',
          style: GoogleFonts.poppins(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Public Speaking'),
              onSubmitted: (v) => Navigator.pop(dialogContext, v),
            ),
            SizedBox(height: 10.h),
            Text(
              'It will be used for this course straight away. We review new '
              'categories before they show up as a filter for students.',
              style: GoogleFonts.poppins(
                  fontSize: 11.sp, color: AppColors.fontGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Suggest'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    try {
      final saved = await CategoryService.suggest(name);
      await _load();
      if (!mounted) return;
      widget.onChanged(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = _names;

    return DropdownButtonFormField<String>(
      initialValue: widget.value,
      isExpanded: true,
      decoration: widget.decoration.copyWith(
        suffixIcon: _loading
            ? Padding(
                padding: EdgeInsets.all(14.w),
                child: const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        for (final name in names)
          DropdownMenuItem(
            value: name,
            child: Row(
              children: [
                Flexible(
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
                if (_isPending(name)) ...[
                  SizedBox(width: 6.w),
                  Text(
                    '(pending review)',
                    style: GoogleFonts.poppins(
                        fontSize: 10.sp, color: AppColors.fontGrey),
                  ),
                ],
              ],
            ),
          ),
        DropdownMenuItem(
          value: _suggestValue,
          child: Row(
            children: [
              Icon(Icons.add, size: 16.sp, color: AppColors.primaryColor),
              SizedBox(width: 6.w),
              Text(
                'Suggest a new category',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      onChanged: widget.enabled
          ? (value) {
              if (value == _suggestValue) {
                _promptForNewCategory();
                return;
              }
              widget.onChanged(value);
            }
          : null,
      validator: (v) =>
          (v == null || v.isEmpty) ? 'Please pick a category' : null,
    );
  }
}
