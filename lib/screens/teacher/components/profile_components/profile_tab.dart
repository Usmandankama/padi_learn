import 'package:flutter/material.dart';
import '../../../../utils/colors.dart';

class ProfileTabBar extends StatelessWidget {
  final TabController tabController;

  const ProfileTabBar({required this.tabController});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabController,
      labelColor: AppColors.primaryColor,
      unselectedLabelColor: Colors.grey,
      indicatorColor: AppColors.primaryColor,
      tabs: const <Widget>[
        Tab(text: 'My Courses'),
        Tab(text: 'Course Reviews'),
      ],
    );
  }
}
