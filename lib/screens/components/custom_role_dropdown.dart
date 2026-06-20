import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../utils/colors.dart';

class CustomRoleDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final Color? borderColor;

  const CustomRoleDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.borderColor,
  });

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final bool hasError = borderColor != null;
    final Color accent = hasError ? borderColor! : AppColors.primaryColor;

    return DropdownButtonFormField<String>(
      value: value,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.primaryColor),
      style: TextStyle(fontSize: 15.sp, color: AppColors.appBlack),
      decoration: InputDecoration(
        labelText: 'Select Role',
        labelStyle: TextStyle(color: AppColors.fontGrey, fontSize: 14.sp),
        filled: true,
        fillColor: const Color(0xFFF4F6F5),
        prefixIcon: Icon(Icons.person_outline, color: accent, size: 20.sp),
        contentPadding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
        enabledBorder:
            _border(hasError ? borderColor! : Colors.transparent, 1.5),
        focusedBorder: _border(accent, 1.6),
        border: _border(hasError ? borderColor! : Colors.transparent, 1.5),
      ),
      items: items.map((role) {
        return DropdownMenuItem<String>(
          value: role,
          child: Text(role),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
