// lib/features/voice/presentation/widgets/waveform_visualizer.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveformVisualizerPainter extends CustomPainter {
  final List<double> waveData;
  final Color waveColor;

  WaveformVisualizerPainter({required this.waveData, required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (waveData.isEmpty) return;
    final paint = Paint()
      ..color = waveColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final sliceWidth = size.width / (waveData.length - 1);
    final midY = size.height / 2;

    path.moveTo(0, midY);
    for (int i = 0; i < waveData.length - 1; i++) {
      final x1 = i * sliceWidth;
      final y1 = midY + (waveData[i] * midY * 0.9 * math.sin(i * 0.5));
      final x2 = (i + 1) * sliceWidth;
      final y2 = midY + (waveData[i + 1] * midY * 0.9 * math.sin((i + 1) * 0.5));
      path.quadraticBezierTo(x1, y1, (x1 + x2) / 2, (y1 + y2) / 2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformVisualizerPainter oldDelegate) => true;
}

