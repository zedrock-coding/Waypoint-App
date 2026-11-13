import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Waypoint Vector Diamond Monogram Logo
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

    final logoGraphic = CustomPaint(
      size: Size(size * 0.5, size * 0.5),
      painter: _WaypointDiamondPainter(color: iconColor),
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
      child: Center(child: logoGraphic),
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

    // SVG: M12 2L2 12l10 10 10-10L12 2zm0 4.5l5.5 5.5-5.5 5.5-5.5-5.5L12 6.5z
    final path = Path();
    // Outer diamond
    path.moveTo(12 * scaleX, 2 * scaleY);
    path.lineTo(2 * scaleX, 12 * scaleY);
    path.lineTo(12 * scaleX, 22 * scaleY);
    path.lineTo(22 * scaleX, 12 * scaleY);
    path.close();

    // Inner cutout diamond
    path.moveTo(12 * scaleX, 6.5 * scaleY);
    path.lineTo(17.5 * scaleX, 12 * scaleY);
    path.lineTo(12 * scaleX, 17.5 * scaleY);
    path.lineTo(6.5 * scaleX, 12 * scaleY);
    path.close();

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaypointDiamondPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
