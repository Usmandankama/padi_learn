import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.h, // Adjust the height as necessary
      width: 50.w, // Adjust the width to accommodate the stacked avatars
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: CircleAvatar(
              radius: 15.r, // Adjust the radius as needed
              backgroundImage: const AssetImage(
                  'assets/images/1.jpg'), // Replace with your asset
            ),
          ),
          Positioned(
            left: 15.w, // Offset each avatar slightly to the right
            child: CircleAvatar(
              radius: 15.r,
              backgroundImage: const AssetImage('assets/images/2.jpg'),
            ),
          ),
          Positioned(
            left: 35.w,
            child: CircleAvatar(
              radius: 15.r,
              backgroundImage: const AssetImage('assets/images/3.jpg'),
            ),
          ),
          Positioned(
            left: 55.w,
            child: CircleAvatar(
              radius: 15.r,
              child: const Text('+52'),
            ),
          ),
        ],
      ),
    );
  }
}
