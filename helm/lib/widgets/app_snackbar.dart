import 'package:flutter/material.dart';

class AppSnackBar {
  static const Color darkSlate = Color(0xFF222528);
  static const Color darkBorder = Color(0xFF3A3D40);
  static const Color mintAccent = Color(0xFF88C0A4);

  /// Shows a small, centered, pill-shaped floating toast with an UNDO button for [duration] (default 5s).
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
        width: 310,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkSlate,
        elevation: 6,
        padding: const EdgeInsets.only(left: 18, right: 8, top: 4, bottom: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
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

  /// Shows a small, centered, pill-shaped floating toast without an action for [duration] (default 5s).
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
        width: 260,
        content: Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
          ),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor ?? darkSlate,
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
    );
  }
}
