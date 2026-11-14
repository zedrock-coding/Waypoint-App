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
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: const Color(0xFF2E7D5A),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE8F5E9),
      onPrimaryContainer: const Color(0xFF1B5E20),
      secondary: const Color(0xFF4A6572),
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1F2328),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF6F8FA),
      surfaceContainer: const Color(0xFFEFF2F5),
      surfaceContainerHigh: const Color(0xFFE4E7EA),
      surfaceContainerHighest: const Color(0xFFD0D7DE),
      error: priorityUrgent,
      onError: Colors.white,
      outline: const Color(0xFF6E7781),
      outlineVariant: const Color(0xFFD0D7DE),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      canvasColor: Colors.white,
      cardColor: Colors.white,
      textTheme: GoogleFonts.geistTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: const Color(0xFF1F2328),
        displayColor: const Color(0xFF1F2328),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFD0D7DE), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: 310,
        backgroundColor: const Color(0xFF24292F),
        contentTextStyle: GoogleFonts.geist(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: mint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: const BorderSide(color: Color(0xFFD0D7DE), width: 1),
        ),
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFD0D7DE),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Theme-Adaptive Color Helpers
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color bg(BuildContext context) =>
      isLight(context) ? const Color(0xFFF6F8FA) : bgDark;

  static Color surface(BuildContext context) =>
      isLight(context) ? Colors.white : surfaceDark;

  static Color surfaceContainerColor(BuildContext context) =>
      isLight(context) ? const Color(0xFFEFF2F5) : surfaceContainer;

  static Color surfaceContainerLowColor(BuildContext context) =>
      isLight(context) ? const Color(0xFFF6F8FA) : surfaceContainerLow;

  static Color surfaceContainerHighColor(BuildContext context) =>
      isLight(context) ? const Color(0xFFE4E7EA) : surfaceContainerHigh;

  static Color surfaceContainerLowestColor(BuildContext context) =>
      isLight(context) ? Colors.white : surfaceContainerLowest;

  static Color borderColor(BuildContext context) =>
      isLight(context) ? const Color(0xFFD0D7DE) : surfaceVariant;

  static Color text(BuildContext context) =>
      isLight(context) ? const Color(0xFF1F2328) : onSurface;

  static Color textMuted(BuildContext context) =>
      isLight(context) ? const Color(0xFF656D76) : onSurfaceVariant;

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
