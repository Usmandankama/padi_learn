import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/services/comment_service.dart';
import 'package:padi_learn/services/supabase.dart';
import 'package:padi_learn/utils/colors.dart';

/// Comment section rendered below the course video.
///
/// Students and the lecturer can post; the lecturer (the course owner) can pin
/// a comment to the top and remove any comment. It is built as a plain [Column]
/// so it can live inside the video page's [SingleChildScrollView].
class CommentsSection extends StatefulWidget {
  final String courseId;

  /// The course owner's id. When it matches the signed-in user, pin / moderate
  /// controls are shown (the "lecturer" abilities).
  final String? ownerId;

  const CommentsSection({
    super.key,
    required this.courseId,
    required this.ownerId,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _posting = false;

  String? get _uid => supabase.auth.currentUser?.id;
  bool get _isLecturer => _uid != null && _uid == widget.ownerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await CommentService.fetch(widget.courseId);
      if (mounted) setState(() => _comments = data);
    } catch (e) {
      debugPrint('Error loading comments: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (text.isEmpty || _posting) return;

    setState(() => _posting = true);
    try {
      final created = await CommentService.add(
        courseId: widget.courseId,
        body: text,
      );
      if (!mounted) return;
      _input.clear();
      _focus.unfocus();
      setState(() => _comments = [..._comments, created]);
      // Re-fetch so ordering (pinned first) and any embeds are authoritative.
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _togglePin(Map<String, dynamic> comment) async {
    final pinned = comment['is_pinned'] == true;
    try {
      await CommentService.setPinned(comment['id'].toString(), !pinned);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update pin: $e')),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> comment) async {
    try {
      await CommentService.delete(comment['id'].toString());
      setState(() => _comments.removeWhere((c) => c['id'] == comment['id']));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.forum_outlined,
                size: 18.sp, color: AppColors.richBlack),
            SizedBox(width: 8.w),
            Text(
              'Comments',
              style: GoogleFonts.poppins(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.richBlack,
              ),
            ),
            SizedBox(width: 6.w),
            if (!_loading)
              Text(
                '(${_comments.length})',
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: AppColors.fontGrey,
                ),
              ),
          ],
        ),
        SizedBox(height: 14.h),
        _buildComposer(),
        SizedBox(height: 18.h),
        if (_loading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                ),
              ),
            ),
          )
        else if (_comments.isEmpty)
          _buildEmpty()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (_, __) => SizedBox(height: 14.h),
            itemBuilder: (_, i) => _buildComment(_comments[i]),
          ),
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.appWhite,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: AppColors.richBlack,
              ),
              decoration: InputDecoration(
                hintText: _isLecturer
                    ? 'Reply to your students…'
                    : 'Ask a question or share a thought…',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: AppColors.fontGrey,
                ),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
              ),
            ),
          ),
          IconButton(
            onPressed: _posting ? null : _post,
            icon: _posting
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                    ),
                  )
                : Icon(Icons.send_rounded,
                    color: AppColors.primaryColor, size: 22.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 34.sp, color: AppColors.lightGrey),
            SizedBox(height: 8.h),
            Text(
              'No comments yet — be the first to ask.',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: AppColors.fontGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> comment) {
    final author = (comment['author'] as Map?) ?? const {};
    final name = (author['name'] ?? 'User').toString();
    final avatar = (author['profile_image_url'] ?? '').toString();
    final role = (author['role'] ?? '').toString();
    final body = (comment['body'] ?? '').toString();
    final pinned = comment['is_pinned'] == true;

    final isInstructor = comment['user_id'] == widget.ownerId;
    final isMine = comment['user_id'] == _uid;
    final canModerate = isMine || _isLecturer;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: pinned ? AppColors.primaryAccent : AppColors.appWhite,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: pinned ? AppColors.primaryColor.withOpacity(0.35) : AppColors.lightGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pinned) ...[
            Row(
              children: [
                Icon(Icons.push_pin, size: 13.sp, color: AppColors.primaryColor),
                SizedBox(width: 4.w),
                Text(
                  'Pinned by lecturer',
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: AppColors.primaryAccent,
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.richBlack,
                            ),
                          ),
                        ),
                        if (isInstructor || role == 'Teacher') ...[
                          SizedBox(width: 6.w),
                          _roleBadge(),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _timeAgo(comment['created_at']),
                      style: GoogleFonts.poppins(
                        fontSize: 10.sp,
                        color: AppColors.fontGrey,
                      ),
                    ),
                  ],
                ),
              ),
              if (canModerate || _isLecturer) _buildMenu(comment, pinned),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              height: 1.5,
              color: AppColors.richBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        'Lecturer',
        style: GoogleFonts.poppins(
          fontSize: 9.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.appWhite,
        ),
      ),
    );
  }

  Widget _buildMenu(Map<String, dynamic> comment, bool pinned) {
    final isMine = comment['user_id'] == _uid;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18.sp, color: AppColors.fontGrey),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        switch (value) {
          case 'pin':
            _togglePin(comment);
            break;
          case 'delete':
            _delete(comment);
            break;
        }
      },
      itemBuilder: (_) => [
        if (_isLecturer)
          PopupMenuItem(
            value: 'pin',
            child: Row(
              children: [
                Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin,
                    size: 16.sp, color: AppColors.richBlack),
                SizedBox(width: 8.w),
                Text(pinned ? 'Unpin' : 'Pin comment',
                    style: GoogleFonts.poppins(fontSize: 12.sp)),
              ],
            ),
          ),
        if (isMine || _isLecturer)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 16.sp, color: Colors.red),
                SizedBox(width: 8.w),
                Text('Delete',
                    style: GoogleFonts.poppins(
                        fontSize: 12.sp, color: Colors.red)),
              ],
            ),
          ),
      ],
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
