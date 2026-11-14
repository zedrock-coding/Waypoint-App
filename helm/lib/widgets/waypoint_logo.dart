import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Waypoint Logo rendering official brand asset with vector fallback
class WaypointLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showBackground;

  const WaypointLogo({
    super.key,
    this.size = 32,
    this.color,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppTheme.mint;

    final logoGraphic = Image.asset(
      'assets/icon/icon.png',
      width: size * (showBackground ? 0.75 : 1.0),
      height: size * (showBackground ? 0.75 : 1.0),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return CustomPaint(
          size: Size(size * 0.5, size * 0.5),
          painter: _WaypointDiamondPainter(color: iconColor),
        );
      },
    );

    if (!showBackground) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: logoGraphic),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.surfaceVariant, width: 1),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: logoGraphic,
        ),
      ),
    );
  }
}

class _WaypointDiamondPainter extends CustomPainter {
  final Color color;

  _WaypointDiamondPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    final outerPath = Path()
      ..moveTo(12 * scaleX, 2 * scaleY)
      ..lineTo(2 * scaleX, 12 * scaleY)
      ..lineTo(12 * scaleX, 22 * scaleY)
      ..lineTo(22 * scaleX, 12 * scaleY)
      ..close();

    final innerPath = Path()
      ..moveTo(12 * scaleX, 6.5 * scaleY)
      ..lineTo(17.5 * scaleX, 12 * scaleY)
      ..lineTo(12 * scaleX, 17.5 * scaleY)
      ..lineTo(6.5 * scaleX, 12 * scaleY)
      ..close();

    final combined = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(combined, paint);
  }

  @override
  bool shouldRepaint(covariant _WaypointDiamondPainter oldDelegate) =>
      oldDelegate.color != color;
}
