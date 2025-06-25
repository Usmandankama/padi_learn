// import 'package:flutter/material.dart';
// import 'package:padi_learn/utils/colors.dart';

// class CenterFloatingNavItem extends StatelessWidget {
//   final IconData icon;
//   final bool isSelected;
//   final VoidCallback onTap;

//   const CenterFloatingNavItem({
//     super.key,
//     required this.icon,
//     required this.onTap,
//     required this.isSelected,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         height: 55,
//         width: 55,
//         decoration: BoxDecoration(
//           color: AppColors.primaryColor,
//           borderRadius: BorderRadius.circular(16),
//           boxShadow: [
//             BoxShadow(
//               color: AppColors.primaryColor.withOpacity(0.3),
//               blurRadius: 10,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Icon(
//           icon,
//           color: Colors.white,
//           size: 28,
//         ),
//       ),
//     );
//   }
// }
