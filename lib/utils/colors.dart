import 'package:flutter/material.dart';

/// Brand colours, and the theme-aware surface palette.
///
/// The distinction matters. The constants here are *fixed* — they mean the same
/// thing in light and dark, because they are either the brand itself or a
/// foreground that always sits on the brand (white on the green button is white
/// in both themes). Anything that describes a **surface or the text on it** is
/// not fixed, and lives in [AppPalette] instead, reached through
/// `AppColors.of(context)`.
///
/// Before this split, `themeMode` switched and 36 files went on painting
/// `appWhite` backgrounds with `richBlack` text, so dark mode produced black
/// text on white cards on a dark ground. The toggle worked; nothing else did.
class AppColors {
  const AppColors._();

  /// The brand green. Deliberately identical in both themes — it is the
  /// identity, and it carries white text at the same contrast either way.
  static const Color primaryColor = Color(0xFF32936F);

  /// 9%-alpha green wash. Translucent, so it composites correctly over a light
  /// or a dark surface without needing a variant.
  static const Color primaryAccent = Color(0x1832936F);

  /// A foreground that always sits on [primaryColor] (or on the nav pill).
  /// Not a background — for those use `AppColors.of(context).surface`.
  static const Color appWhite = Colors.white;

  static const Color appBlack = Colors.black;

  /// The dark navy. Still used as a *deliberate* dark fill (the nav pill), and
  /// as the light theme's ink.
  static const Color richBlack = Color(0xFF0D1B2A);

  static const Color fontGrey = Color(0xFF707070);
  static const Color lightGrey = Color.fromARGB(255, 217, 217, 217);
  static const Color beige = Color(0xFF253031);

  /// The surface palette for the current theme.
  ///
  /// Prefer this in a `build` that already has a context.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? AppPalette.light;

  /// The current palette, without needing a `BuildContext`.
  ///
  /// A deliberate trade. Much of this app paints from helper methods that were
  /// never given a context (`Widget _buildStats(TeacherController c)` and its
  /// like), so a context-only API would have meant changing dozens of
  /// signatures across 36 files to fix a colour bug. This is bound once per
  /// frame from `MyApp`'s builder, above the Navigator, so it is always set
  /// before any screen builds.
  ///
  /// It holds because the app has exactly one `MaterialApp` and never renders
  /// two themes at once. If that ever stops being true — a themed preview pane,
  /// a per-subtree `Theme` — switch those widgets to [of] and pass the context.
  static AppPalette palette = AppPalette.light;

  /// Called from the app builder each frame. Not for use anywhere else.
  static void bind(ThemeData theme) {
    palette = theme.extension<AppPalette>() ?? AppPalette.light;
  }

  /// Subscribes this widget to theme changes, and refreshes [palette].
  ///
  /// Call once at the top of `build`. Reading the static [palette] on its own
  /// creates **no dependency** on the `Theme` inherited widget, so a screen
  /// that only did that never rebuilt when the mode flipped — it kept painting
  /// whatever colours it resolved the first time, and switching to light mode
  /// left a dark screen with a light strip where the Scaffold (which does
  /// depend on the theme) had repainted underneath it.
  ///
  /// `Theme.of` here is what registers the dependency. Refreshing the static at
  /// the same time is what keeps the context-free helper methods correct, since
  /// they re-run as part of the rebuild this triggers.
  static AppPalette watch(BuildContext context) {
    final resolved =
        Theme.of(context).extension<AppPalette>() ?? AppPalette.light;
    palette = resolved;
    return resolved;
  }
}

/// Surfaces, and the ink that goes on them.
///
/// Five tokens rather than a full design system, on purpose: these are the ones
/// the app actually breaks without. Everything else it paints is either brand
/// or translucent, and works unchanged on both grounds.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// The screen behind everything. Was a hard-coded `0xFFF7F8FA`.
  final Color ground;

  /// Cards, sheets, app bars, list rows — anything lifted off [ground].
  final Color surface;

  /// A recessed fill on top of [surface]: input backgrounds, chips, wells.
  final Color surfaceAlt;

  /// Primary text and icons.
  final Color ink;

  /// Secondary text, captions, disabled icons.
  final Color inkSoft;

  /// Dividers, borders, outlines.
  final Color hairline;

  const AppPalette({
    required this.ground,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.hairline,
  });

  static const AppPalette light = AppPalette(
    ground: Color(0xFFF7F8FA),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF1F3F5),
    ink: Color(0xFF0D1B2A),
    inkSoft: Color(0xFF707070),
    hairline: Color.fromARGB(255, 217, 217, 217),
  );

  /// Not an inversion of [light]. The ground is a desaturated navy rather than
  /// black so the brand green does not vibrate against it, and the inks stop
  /// short of pure white, which glares on an OLED phone at night — the way this
  /// app is most likely to be read.
  static const AppPalette dark = AppPalette(
    ground: Color(0xFF0F1417),
    surface: Color(0xFF171E23),
    surfaceAlt: Color(0xFF1F282E),
    ink: Color(0xFFE6EDF1),
    inkSoft: Color(0xFF95A4AD),
    hairline: Color(0xFF2B353C),
  );

  @override
  AppPalette copyWith({
    Color? ground,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkSoft,
    Color? hairline,
  }) {
    return AppPalette(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      hairline: hairline ?? this.hairline,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
    );
  }
}
