import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:padi_learn/utils/colors.dart';

/// The floating pill nav.
///
/// It sits in the Scaffold's `bottomNavigationBar` slot, which on Android 15+
/// (and any gesture-navigation device) extends *behind* the system navigation
/// bar — Flutter draws edge-to-edge by default at this target SDK and there is
/// no opting out. A fixed bottom margin therefore put the pill underneath the
/// device's own navigation: partly hidden behind three-button navigation, and
/// inside the gesture-handle strip, which swallows touches.
///
/// So the gap below the pill is measured from whatever the system reserves
/// rather than assumed. `viewPadding` — not `padding` — is deliberate: it keeps
/// reporting the navigation bar's height while the keyboard is open, and the
/// pill is pushed off-screen by the keyboard anyway.
class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  /// The pill itself, as opposed to the full-width slot it floats in.
  @visibleForTesting
  static const Key pillKey = ValueKey('bottom-nav-pill');

  /// Clear space between the pill and the system navigation (or the screen
  /// edge, on devices that reserve nothing).
  static const double _floatGap = 12;

  /// Never hug the very bottom, even with no system inset at all.
  static const double _minInset = 12;

  /// Stops the pill stretching into a near-full-width bar on tablets, where
  /// three centred icons in a 900px pill look lost.
  static const double _maxWidth = 340;

  /// Sized in logical pixels, not ScreenUtil units, to match the icon and its
  /// padding. Scaling only some of the three is what makes the row overflow
  /// its own pill on screens far from the design size.
  static const double _pillHeight = 70;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = math.max(media.viewPadding.bottom, _minInset);
    final width = math.min(media.size.width - 120, _maxWidth);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset + _floatGap),
      // Scaffold hands this slot a *tight* full-width constraint, so the pill
      // cannot size itself: it needs a full-width parent to be centred within.
      // (The Stack this replaces was doing that job, not decorating.)
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Container(
          key: pillKey,
          height: _pillHeight,
          width: width,
          decoration: BoxDecoration(
            color: AppColors.richBlack,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Expanded, so three items always divide whatever width the pill
              // ended up with instead of overflowing it — and so the tap
              // target is a full third of the pill, not just the icon.
              _navItem(Icons.home_rounded, 0, 'Home'),
              _navItem(Icons.library_books_rounded, 1, 'Courses'),
              _navItem(Icons.person_rounded, 2, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index, String label) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: Semantics(
        label: label,
        selected: isSelected,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onItemTapped(index),
          child: Center(
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
          ),
        ),
      ),
    );
  }
}
