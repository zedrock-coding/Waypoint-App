import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String fullName;
  final double radius;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    required this.fullName,
    this.avatarUrl,
    this.radius = 20,
    this.backgroundColor,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Color _getNameColor(String name) {
    final int hash = name.hashCode;
    final List<Color> colors = [
      Colors.teal,
      Colors.indigo,
      Colors.blueGrey,
      Colors.brown,
      Colors.deepPurple,
      Colors.blueAccent,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final String initials = _getInitials(fullName);
    final Color bgColor = backgroundColor ?? _getNameColor(fullName);

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor.withOpacity(0.1),
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback handled by the "child" when background image fails
        },
        child: null,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
          letterSpacing: initials.length > 1 ? -1 : 0,
        ),
      ),
    );
  }
}
