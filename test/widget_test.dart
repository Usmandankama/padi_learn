// Regression cover for the two things most likely to break silently on a
// device we don't have in front of us: where the floating nav pill sits
// relative to the system navigation bar, and how money is spelled.
//
// This file used to be the generated counter smoke test — it tapped an
// Icons.add that does not exist in this app and pumped MyApp without the
// controllers main() registers, so it could only ever fail.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:padi_learn/screens/home/components/bottom_nav_bar.dart';
import 'package:padi_learn/utils/money.dart';
import 'package:padi_learn/utils/colors.dart';
import 'package:padi_learn/screens/marketplace/components/course_card.dart';
import 'package:padi_learn/screens/description/components/price_tag.dart';
import 'package:padi_learn/screens/marketplace/marketplace_screen.dart';

/// Builds the shell the way HomeShell does — pill in the bottomNavigationBar
/// slot — under a device whose system navigation reserves [systemInset].
Widget _shell({required double systemInset}) {
  // MediaQuery outside ScreenUtilInit: ScreenUtil reads the nearest one, and
  // if it sits above this it scales against the bare 800x600 test window
  // instead of the device being emulated.
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(393, 852),
      viewPadding: EdgeInsets.only(bottom: systemInset),
      padding: EdgeInsets.only(bottom: systemInset),
    ),
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: CustomBottomNavBar(
            selectedIndex: 0,
            onItemTapped: (_) {},
          ),
        ),
      ),
    ),
  );
}

/// Distance from the bottom of the pill to the bottom of the screen.
double _gapBelowPill(WidgetTester tester) {
  final pill = tester.getRect(find.byKey(CustomBottomNavBar.pillKey));
  final screen = tester.getRect(find.byType(MaterialApp));
  return screen.bottom - pill.bottom;
}

void main() {
  group('floating nav pill vs. the device navigation bar', () {
    // Three-button navigation is the tallest thing the system reserves, and
    // the case the old fixed 30px margin lost outright: the pill's lower half
    // sat behind the Back/Home/Recents buttons.
    testWidgets('clears three-button navigation', (tester) async {
      await tester.pumpWidget(_shell(systemInset: 48));
      expect(_gapBelowPill(tester), greaterThanOrEqualTo(48));
    });

    // Gesture navigation reserves less, but the strip it does reserve swallows
    // touches — a button inside it cannot be tapped at all.
    testWidgets('clears a gesture handle', (tester) async {
      await tester.pumpWidget(_shell(systemInset: 24));
      expect(_gapBelowPill(tester), greaterThanOrEqualTo(24));
    });

    // And on a device that reserves nothing, the pill must still not be glued
    // to the screen edge.
    testWidgets('still floats with no system inset', (tester) async {
      await tester.pumpWidget(_shell(systemInset: 0));
      final gap = _gapBelowPill(tester);
      expect(gap, greaterThan(0));
      expect(gap, lessThan(48)); // ...but does not waste half the screen.
    });

    // Scaffold constrains this slot to the full screen width; the pill has to
    // stay a centred pill inside it rather than becoming a full-width bar.
    testWidgets('stays a centred pill, not a full-width bar', (tester) async {
      await tester.pumpWidget(_shell(systemInset: 24));
      final pill = tester.getRect(find.byKey(CustomBottomNavBar.pillKey));
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(pill.width, lessThan(screen.width));
      expect(pill.center.dx, closeTo(screen.center.dx, 0.5));
    });

    testWidgets('taller system navigation pushes the pill further up',
        (tester) async {
      await tester.pumpWidget(_shell(systemInset: 0));
      final short = _gapBelowPill(tester);
      await tester.pumpWidget(_shell(systemInset: 48));
      expect(_gapBelowPill(tester), greaterThan(short));
    });
  });

  group('dark mode', () {
    // The bug this covers: themeMode switched but 36 files went on painting
    // white surfaces with near-black text, so dark mode rendered black text on
    // white cards on a dark ground.
    test('the two palettes are genuinely different surfaces', () {
      expect(AppPalette.dark.ground, isNot(AppPalette.light.ground));
      expect(AppPalette.dark.surface, isNot(AppPalette.light.surface));
      expect(AppPalette.dark.ink, isNot(AppPalette.light.ink));
    });

    test('ink stays legible against its own ground in both themes', () {
      double lum(Color c) => c.computeLuminance();
      // Dark theme: light ink on a dark ground. Light theme: the reverse.
      expect(
          lum(AppPalette.dark.ink), greaterThan(lum(AppPalette.dark.ground)));
      expect(lum(AppPalette.light.ink), lessThan(lum(AppPalette.light.ground)));
    });

    testWidgets('a bare Scaffold picks up the dark ground from the theme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[AppPalette.dark],
            scaffoldBackgroundColor: AppPalette.dark.ground,
          ),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );
      final scaffold = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(scaffold.color, AppPalette.dark.ground);
    });

    // The bug found on device: flipping to light mode left a dark screen.
    // Reading the static AppColors.palette creates no dependency on the Theme
    // inherited widget, so screens already in the Navigator never rebuilt --
    // they kept painting whatever they resolved on first build.
    testWidgets('a screen repaints when the theme mode flips', (tester) async {
      final mode = ValueNotifier<ThemeMode>(ThemeMode.dark);
      addTearDown(mode.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (_, m, __) => MaterialApp(
            themeMode: m,
            theme: ThemeData(
              extensions: const <ThemeExtension<dynamic>>[AppPalette.light],
            ),
            darkTheme: ThemeData(
              extensions: const <ThemeExtension<dynamic>>[AppPalette.dark],
            ),
            home: const _PaletteProbe(),
          ),
        ),
      );

      Color painted() =>
          (tester.widget<ColoredBox>(find.byKey(const ValueKey('probe'))))
              .color;

      expect(painted(), AppPalette.dark.ground);

      mode.value = ThemeMode.light;
      await tester.pumpAndSettle();

      expect(painted(), AppPalette.light.ground,
          reason: 'the screen must repaint when the theme mode changes');
    });

    testWidgets('AppColors.of resolves the palette the theme carries',
        (tester) async {
      late AppPalette seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[AppPalette.dark],
          ),
          home: Builder(builder: (context) {
            seen = AppColors.of(context);
            return const SizedBox.shrink();
          }),
        ),
      );
      expect(seen.ground, AppPalette.dark.ground);
    });
  });

  group('courses the student already owns', () {
    Widget host(Widget child) => ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
        );

    const course = <String, dynamic>{
      'id': 'c1',
      'title': 'Start a Small Business',
      'author': 'Ada',
      'price': 5000,
      'enrollments': 12,
    };

    testWidgets('a card shows the price when it is still for sale',
        (tester) async {
      await tester.pumpWidget(host(
        CourseCard(course: course, onTap: () {}),
      ));
      await tester.pump();
      expect(find.text('NGN 5,000'), findsOneWidget);
      expect(find.text('Owned'), findsNothing);
    });

    testWidgets('a card shows ownership instead of a price once bought',
        (tester) async {
      await tester.pumpWidget(host(
        CourseCard(course: course, isOwned: true, onTap: () {}),
      ));
      await tester.pump();
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('NGN 5,000'), findsNothing,
          reason: 'a price you cannot act on is noise');
    });

    testWidgets('the course page price tag follows the same rule',
        (tester) async {
      await tester.pumpWidget(host(const PriceTag(price: 5000)));
      await tester.pump();
      expect(find.text('NGN 5,000'), findsOneWidget);

      await tester.pumpWidget(host(const PriceTag(price: 5000, isOwned: true)));
      await tester.pump();
      expect(find.text('Owned'), findsOneWidget);
    });

    // Free courses are enrolments too. "Purchased" would be a small lie.
    testWidgets('a free course that was taken reads as owned, not purchased',
        (tester) async {
      await tester.pumpWidget(host(const PriceTag(price: 0, isOwned: true)));
      await tester.pump();
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('Free'), findsNothing);
    });
  });

  group('what the marketplace lists', () {
    final catalogue = [
      <String, dynamic>{'id': 'a', 'title': 'Bought already'},
      <String, dynamic>{'id': 'b', 'title': 'Still for sale'},
    ];
    List<String> ids(List<Map<String, dynamic>> l) =>
        l.map((c) => c['id'] as String).toList();

    test('browsing hides what the student already owns', () {
      final shown = visibleCourses(
        catalogue: catalogue,
        owned: {'a'},
        isSearching: false,
      );
      expect(ids(shown), ['b']);
    });

    // Typing a course's name and getting nothing back reads as "we don't have
    // it" rather than "you already own it" -- the more confusing of the two.
    test('an explicit search still finds a course you own', () {
      final shown = visibleCourses(
        catalogue: catalogue,
        owned: {'a'},
        isSearching: true,
      );
      expect(ids(shown), ['a', 'b']);
    });

    test('owning nothing changes nothing', () {
      expect(
        ids(visibleCourses(
            catalogue: catalogue, owned: {}, isSearching: false)),
        ['a', 'b'],
      );
    });

    test('owning everything empties the shelf but not the search', () {
      expect(
        visibleCourses(
            catalogue: catalogue, owned: {'a', 'b'}, isSearching: false),
        isEmpty,
      );
      expect(
        ids(visibleCourses(
            catalogue: catalogue, owned: {'a', 'b'}, isSearching: true)),
        ['a', 'b'],
      );
    });
  });

  group('money formatting', () {
    test('free courses say so rather than showing a zero', () {
      expect(formatPriceLabel(0), 'Free');
      expect(formatPriceLabel(-1), 'Free');
    });

    test('amounts are grouped and carry one consistent currency spelling', () {
      expect(formatPriceLabel(5000), 'NGN 5,000');
      expect(formatNaira(1250000), 'NGN 1,250,000');
      expect(formatNaira(999), 'NGN 999');
    });

    test('kobo are rounded away, never truncated', () {
      expect(formatNaira(2499.6), 'NGN 2,500');
    });

    test('counts stay compact', () {
      expect(formatStudentCount(1200), '1.2k');
      expect(formatStudentCount(999), '999');
      expect(formatStudentCount(2500000), '2.5M');
    });
  });
}

/// Mimics how the converted screens paint: `watch` at the top of `build`, then
/// colours read from the context-free static.
class _PaletteProbe extends StatelessWidget {
  const _PaletteProbe();

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return ColoredBox(
      key: const ValueKey('probe'),
      color: AppColors.palette.ground,
      child: const SizedBox.expand(),
    );
  }
}
