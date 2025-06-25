import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:padi_learn/screens/settings/settings_screen.dart';
import 'package:padi_learn/utils/colors.dart';

import '../../controller/teacherController.dart';
import 'components/profile_components/profile_actions.dart';
import 'components/profile_components/profile_header.dart';
import 'components/profile_components/profile_stats.dart';
import 'components/profile_components/profile_tab.dart';
import 'components/profile_components/profile_tabBarView.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  _TeacherProfileScreenState createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeacherController controller = Get.find();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appWhite,
      appBar: AppBar(
        backgroundColor: AppColors.appWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.primaryColor),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            ProfileHeader(controller: controller), // ProfileHeader widget
            ProfileStats(controller: controller), // ProfileStats widget
            const ProfileActions(), // ProfileActions widget
            ProfileTabBar(
                tabController: _tabController), // ProfileTabBar widget
            ProfileTabBarView(
                tabController: _tabController), // ProfileTabBarView widget
          ],
        ),
      ),
    );
  }
}
