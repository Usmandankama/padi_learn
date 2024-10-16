import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controller/marketplace_controller.dart';

class CategorySelection extends StatefulWidget {
  @override
  _CategorySelectionState createState() => _CategorySelectionState();
}

class _CategorySelectionState extends State<CategorySelection> {
  List<String> categories = ['All', 'Programming', 'Design', 'Marketing'];
  String selectedCategory = 'All'; // Default selected category

  @override
  Widget build(BuildContext context) {
    final MarketplaceController controller = Get.find<MarketplaceController>();
    return Wrap(
      spacing: 10.0, // Spacing between containers
      children: categories.map((category) {
        bool isSelected = controller.selectedFilter.value == category;

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedCategory = category;
              controller.selectedFilter.value = category;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue
                  : Colors.grey[300], // Highlight selected category
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
