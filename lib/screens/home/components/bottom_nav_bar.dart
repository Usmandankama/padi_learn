import 'package:flutter/material.dart';
import 'package:padi_learn/utils/colors.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Main pill container
        Container(
          height: 70,
          width: MediaQuery.of(context).size.width - 120,
          margin: const EdgeInsets.only(bottom: 30),
          decoration: BoxDecoration(
            color: AppColors.richBlack,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _navItem(Icons.home_rounded, 0),
              const SizedBox(width: 20),
              _navItem(Icons.library_books_rounded, 1), // "My Courses"
              const SizedBox(width: 20),
              _navItem(Icons.person_rounded, 2),
            ],
          ),
        ),

        // Center floating icon
      ],
    );
  }

  Widget _navItem(IconData icon, int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.primaryColor : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
