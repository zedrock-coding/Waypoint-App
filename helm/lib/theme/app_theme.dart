import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Obsidian Precision Color Palette
  static const Color bgDark = Color(0xFF111417);
  static const Color surfaceDark = Color(0xFF111417);
  static const Color surfaceContainerLowest = Color(0xFF0B0F11);
  static const Color surfaceContainerLow = Color(0xFF191C1F);
  static const Color surfaceContainer = Color(0xFF1D2023);
  static const Color surfaceContainerHigh = Color(0xFF272A2D);
  static const Color surfaceContainerHighest = Color(0xFF323538);
  static const Color surfaceVariant = Color(0xFF323538);

  static const Color outline = Color(0xFF8A938C);
  static const Color outlineVariant = Color(0xFF404943);

  static const Color onSurface = Color(0xFFE1E2E6);
  static const Color onSurfaceVariant = Color(0xFFC0C9C2);

  static const Color mint = Color(0xFF88C0A4);
  static const Color mintHover = Color(0xFF9ECBB5);
  static const Color onMint = Color(0xFF1E2124);

  // Priority Accents
  static const Color priorityUrgent = Color(0xFFFF5252);
  static const Color priorityHigh = Color(0xFFFFBF00);
  static const Color priorityMedium = Color(0xFF88C0A4);
  static const Color priorityLow = Color(0xFF78909C);

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: mint,
      onPrimary: onMint,
      primaryContainer: mint.withValues(alpha: 0.2),
      onPrimaryContainer: mint,
      secondary: const Color(0xFFB9C8DE),
      onSecondary: const Color(0xFF233143),
      surface: surfaceDark,
      onSurface: onSurface,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      error: priorityUrgent,
      onError: Colors.white,
      outline: outline,
      outlineVariant: outlineVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgDark,
      canvasColor: surfaceDark,
      cardColor: surfaceContainerHigh,
      textTheme: GoogleFonts.geistTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: surfaceVariant, width: 1),
        ),
        color: surfaceContainerHigh,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: 310,
        backgroundColor: surfaceContainerHigh,
        contentTextStyle: GoogleFonts.geist(
          color: onSurface,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: mint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: const BorderSide(color: surfaceVariant, width: 1),
        ),
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get lightTheme {
    // Keep lightTheme as an alternative, styled cleanly
    final ColorScheme lightScheme = ColorScheme.fromSeed(
      seedColor: mint,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      textTheme: GoogleFonts.geistTextTheme(ThemeData.light().textTheme),
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: 310,
        backgroundColor: const Color(0xFF222528),
        contentTextStyle: GoogleFonts.geist(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: mint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: const BorderSide(color: Color(0xFF3A3D40), width: 1),
        ),
        elevation: 6,
      ),
    );
  }

  // Monospace helper for labels, tags, and IDs
  static TextStyle monoStyle({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? onSurfaceVariant,
      letterSpacing: letterSpacing,
    );
  }

  static final fontScales = [0.7, 0.85, 1.0, 1.2, 1.4];
}
