import 'package:flutter/material.dart';

class SiftTheme {
  // Cognition Specific Colors (Audit Result)
  static const Color background = Color(0xFF131314);
  static const Color surface = Color(0xFF1E1E20);
  static const Color surfaceBright = Color(0xFF28292A);
  static const Color primary = Color(0xFFD0BCFF);
  static const Color secondary = Color(0xFFCCC2DC);
  static const Color outline = Color(0xFF444746);
  static const Color outlineVariant = Color(0xFF303030);

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
    );
  }
}
