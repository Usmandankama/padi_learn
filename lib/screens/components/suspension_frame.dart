import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:padi_learn/services/suspension_service.dart';
import 'package:padi_learn/utils/app_info.dart';
import 'package:padi_learn/utils/colors.dart';

/// Puts a notice above [child] while the account is suspended, saying why,
/// what still works, and where to appeal. Draws [child] alone otherwise.
///
/// Checked once, when the shell is built. A suspension that starts while the
/// app is open shows on the next launch; until then the database still
/// refuses the actions, so nothing is lost but the explanation.
class SuspensionFrame extends StatefulWidget {
  const SuspensionFrame({
    super.key,
    required this.child,
    this.load = SuspensionService.mine,
  });

  final Widget child;

  /// Only a test passes anything else.
  final Future<Suspension?> Function() load;

  @override
  State<SuspensionFrame> createState() => _SuspensionFrameState();
}

class _SuspensionFrameState extends State<SuspensionFrame> {
  Suspension? _suspension;

  @override
  void initState() {
    super.initState();
    widget.load().then((s) {
      if (mounted && s != null) setState(() => _suspension = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final suspension = _suspension;
    if (suspension == null) return widget.child;

    final error = Theme.of(context).colorScheme.error;

    return Column(
      children: [
        Material(
          color: error.withValues(alpha: 0.1),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.block, color: error, size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Your account is suspended'
                      '${suspension.reason.isEmpty ? '' : ': ${suspension.reason}'}. '
                      'You can still watch the courses you have, but not post, '
                      'upload, buy or change your details. To appeal, email '
                      '$kSupportEmail.',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: AppColors.palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // The banner already sits below the status bar, so the screens under
        // it must not pad for it a second time.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
