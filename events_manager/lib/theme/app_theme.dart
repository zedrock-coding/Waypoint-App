import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final ColorScheme lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF26A69A), // Teal/Mint
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F6F8), // Soft off-white
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final ColorScheme slateScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF88C0A4), 
      brightness: Brightness.dark,
      surface: const Color(0xFF1E2124),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: slateScheme,
      scaffoldBackgroundColor: const Color(0xFF1E2124),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF2A2D32),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }

  static final fontScales = [0.7, 0.85, 1.0, 1.2, 1.4];
}
