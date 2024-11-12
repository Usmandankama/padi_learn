import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class CustomRoleDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const CustomRoleDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged, MaterialColor? borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: 'Select Role',
        prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
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
