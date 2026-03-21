import 'package:flutter/material.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

class SiftTheme {
  /// Global highlighter themes for VSCode-like code display.
  static late final HighlighterTheme lightCodeTheme;
  static late final HighlighterTheme darkCodeTheme;

  // Cognition Specific Colors (Audit Result)
  static const Color background = Color(0xFF0E0E0E);
  static const Color surface = Color(0xFF171719);
  static const Color surfaceBright = Color(0xFF28292A);
  static const Color primary = Color(0xFFD0BCFF);
  static const Color secondary = Color(0xFFCCC2DC);
  static const Color outline = Color(0xFF444746);
  static const Color outlineVariant = Color(0xFF252525);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
        surface: background,
        onSurface: Colors.white,
        surfaceContainerHigh: surface,
        surfaceContainerHighest: surfaceBright,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: background,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)) {
            return 8.0;
          }
          return 4.0;
        }),
        thumbColor: WidgetStateProperty.all(primary.withValues(alpha: 0.2)),
        radius: const Radius.circular(8),
        interactive: true,
      ),
    );
  }
}
