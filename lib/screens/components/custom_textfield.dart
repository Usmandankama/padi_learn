import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:padi_learn/utils/colors.dart';

class CustomTextfield extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextEditingController controller;
  final Color? borderColor;
  final TextInputType? keyboardType;

  const CustomTextfield({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.borderColor,
    this.keyboardType,
  });

  @override
  State<CustomTextfield> createState() => _CustomTextfieldState();
}

class _CustomTextfieldState extends State<CustomTextfield> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.borderColor != null;
    final Color accent = hasError ? widget.borderColor! : AppColors.primaryColor;

    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      style: TextStyle(fontSize: 15.sp, color: AppColors.appBlack),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: AppColors.fontGrey, fontSize: 14.sp),
        filled: true,
        fillColor: const Color(0xFFF4F6F5),
        prefixIcon: Icon(widget.icon, color: accent, size: 20.sp),
        suffixIcon: widget.obscureText
            ? IconButton(
                splashRadius: 20.r,
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.fontGrey,
                  size: 20.sp,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
        contentPadding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
        enabledBorder:
            _border(hasError ? widget.borderColor! : Colors.transparent, 1.5),
        focusedBorder: _border(accent, 1.6),
        border:
            _border(hasError ? widget.borderColor! : Colors.transparent, 1.5),
      ),
    );
  }
}
