import 'package:flutter/material.dart';

class AppSnackBar {
  static const Color darkSlate = Color(0xFF2D2F31);
  static const Color darkBorder = Color(0xFF3E4145);
  static const Color mintAccent = Color(0xFF88C0A4);

  /// Shows a floating themed toast with an UNDO button visible for [duration] (default 5s).
  static void showUndo({
    required BuildContext context,
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: mintAccent,
          onPressed: onUndo,
        ),
      ),
    );
  }

  /// Shows a floating themed toast without an action, visible for [duration] (default 5s).
  static void show({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 5),
    Color? backgroundColor,
    Color? textColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor ?? darkSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
    );
  }
}

