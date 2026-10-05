import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Layout rules for running the same app on a phone and on a desktop browser.
///
/// The breakpoints match the ones the marketplace grid already used, so the
/// whole app agrees on what "wide" means instead of each screen inventing it.
class Breakpoints {
  const Breakpoints._();

  /// Phones, and a browser window narrowed to roughly phone size.
  static const double compact = 720;

  /// Tablets and small laptop windows.
  static const double expanded = 1100;

  /// Widest a column of running text or a form should ever get. Beyond this
  /// the eye loses the start of the next line.
  static const double readable = 560;

  /// Widest the main content column should get. Grids look thin and lost if
  /// they are allowed to stretch across a 2560px monitor.
  static const double content = 1200;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Phone layout: bottom nav, single column, full-bleed content.
  bool get isCompact => screenWidth < Breakpoints.compact;

  /// Side navigation rail replaces the bottom pill.
  bool get isWide => screenWidth >= Breakpoints.compact;

  /// Room for a third or fourth grid column.
  bool get isExpanded => screenWidth >= Breakpoints.expanded;
}

/// The design size handed to ScreenUtil.
///
/// ScreenUtil scales every `.sp`, `.w` and `.h` by `screenWidth / designWidth`.
/// With a fixed 393pt design width that multiplier hits about 4.9x on a 1920px
/// monitor, which is why the web build rendered as a phone layout with
/// enormous type — nothing was wrong with the layouts themselves.
///
/// Rather than rewrite fifty screens, this caps the multiplier: the design
/// width grows with the window so the scale factor never passes [_maxScale].
///
/// **Mobile is deliberately untouched.** Off the web this returns the original
/// 393x852 exactly, so native builds render as they always have — and even on
/// a mobile browser the clamp does nothing below about 450pt, because the
/// design width floor still wins there.
Size responsiveDesignSize(Size screen) {
  const design = Size(393, 852);
  if (!kIsWeb) return design;

  // 1.15 keeps type a touch larger than the phone design on a big monitor,
  // which reads correctly at desktop viewing distance, without ballooning.
  const maxScale = 1.15;

  return Size(
    math.max(design.width, screen.width / maxScale),
    math.max(design.height, screen.height / maxScale),
  );
}

/// Centres a screen's content and stops it stretching across a wide monitor.
///
/// Mobile is a no-op: below the max width this adds nothing but the padding
/// the screen asked for, so wrapping a screen in it cannot change the phone
/// layout.
class PageBody extends StatelessWidget {
  final Widget child;

  /// Defaults to [Breakpoints.content]. Pass [Breakpoints.readable] for forms
  /// and anything that is mostly prose.
  final double maxWidth;

  /// Horizontal breathing room once the content stops touching the edges.
  final EdgeInsetsGeometry padding;

  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.content,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    // Centring with symmetric padding rather than Align/Center is deliberate.
    // Align hands its child *loose* constraints in both axes, so a child that
    // is meant to fill the height — a PageView, a ListView, a Column with an
    // Expanded — collapses to nothing. Padding passes the parent's constraints
    // straight through minus the inset, so a fill-height body stays a
    // fill-height body and only the width is restricted.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, maxWidth);
        final gutter = math.max(0.0, (constraints.maxWidth - width) / 2);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Padding(padding: padding, child: child),
        );
      },
    );
  }
}

/// Columns for a card grid at the current width.
///
/// One definition, so the marketplace and the dashboard cannot drift apart.
int gridColumnsFor(double width) {
  // Stops at four on purpose. Content is capped at [Breakpoints.content], so a
  // fifth column would mean roughly 230pt cards — narrow enough that course
  // titles ellipsise on almost every card, which reads as broken rather than
  // dense.
  if (width >= Breakpoints.expanded) return 4;
  if (width >= Breakpoints.compact) return 3;
  return 2;
}
