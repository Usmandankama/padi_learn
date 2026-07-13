import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/screens/videoplayer/videoPlayer.dart';
import 'package:padi_learn/services/notification_service.dart';
import 'package:padi_learn/utils/colors.dart';

/// Lecturer notification inbox: new comments and new enrollments, live.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.richBlack),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            color: AppColors.richBlack,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => NotificationService.markAllRead(),
            child: Text(
              'Mark all read',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationService.stream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
            );
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) return _empty();

          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) => _NotificationTile(item: items[i]),
          );
        },
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 56.sp, color: AppColors.lightGrey),
          SizedBox(height: 12.h),
          Text(
            'No notifications yet',
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.richBlack,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            "You'll hear here when students enrol or comment.",
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: AppColors.fontGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final unread = item['is_read'] != true;
    final type = (item['type'] ?? '').toString();
    final isComment = type == 'comment';

    return Dismissible(
      key: ValueKey(item['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => NotificationService.delete(item['id'].toString()),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () {
          if (unread) NotificationService.markRead(item['id'].toString());
          final courseId = (item['course_id'] ?? '').toString();
          if (courseId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerPage(courseId: courseId),
              ),
            );
          }
        },
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: unread ? AppColors.primaryAccent : AppColors.appWhite,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.lightGrey),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isComment
                      ? Icons.mode_comment_outlined
                      : Icons.shopping_bag_outlined,
                  size: 20.sp,
                  color: AppColors.primaryColor,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['message'] ?? '').toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        height: 1.4,
                        fontWeight:
                            unread ? FontWeight.w600 : FontWeight.w500,
                        color: AppColors.richBlack,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _timeAgo(item['created_at']),
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        color: AppColors.fontGrey,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  margin: EdgeInsets.only(left: 6.w, top: 4.h),
                  width: 9.w,
                  height: 9.w,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(dynamic iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso.toString())?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
