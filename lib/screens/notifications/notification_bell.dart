import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/notifications/notifications_screen.dart';
import 'package:padi_learn/services/notification_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// App-bar bell that opens the notifications inbox and shows a live unread
/// count badge driven by the realtime notifications stream.
class NotificationBell extends StatefulWidget {
  final Color? iconColor;
  const NotificationBell({super.key, this.iconColor});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  /// Built once. Creating the stream inside `build` opened a new realtime
  /// subscription every time the surrounding app bar rebuilt.
  late final Stream<List<Map<String, dynamic>>> _notifications =
      NotificationService.stream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notifications,
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? const [])
            .where((n) => n['is_read'] != true)
            .length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none_rounded,
                  color: widget.iconColor ?? AppColors.primaryColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            if (unread > 0)
              Positioned(
                right: 6.w,
                top: 6.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  constraints: BoxConstraints(minWidth: 16.w),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.appWhite, width: 1.5),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.appWhite,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
