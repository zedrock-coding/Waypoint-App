import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive audio waveform visualizer widget matching Waypoint's
/// Dark Slate (#1E2124) and Mint Green (#88C0A4) design system.
///
/// Features smooth physics-based dampening, idle ambient oscillation,
/// and responsive voice bounce driven by an incoming amplitude stream.
class AudioWaveformVisualizer extends StatefulWidget {
  final Stream<double>? amplitudeStream;
  final int barCount;
  final double height;
  final double barWidth;
  final double barSpacing;
  final Color activeColor;
  final Color? idleColor;
  final bool isRecording;

  const AudioWaveformVisualizer({
    super.key,
    this.amplitudeStream,
    this.barCount = 9,
    this.height = 48.0,
    this.barWidth = 4.0,
    this.barSpacing = 4.0,
    this.activeColor = const Color(0xFF88C0A4),
    this.idleColor,
    this.isRecording = true,
  }) : assert(barCount >= 3, 'barCount must be at least 3');

  @override
  State<AudioWaveformVisualizer> createState() => _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  StreamSubscription<double>? _amplitudeSub;

  double _currentAmplitude = 0.0;
  double _smoothedAmplitude = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _animController.addListener(_onTick);
    _subscribeToStream();
  }

  void _onTick() {
    if (!mounted) return;
    // Smooth lerp towards target amplitude; AnimatedBuilder rebuilds each tick
    _smoothedAmplitude += (_currentAmplitude - _smoothedAmplitude) * 0.3;
  }

  void _subscribeToStream() {
    _amplitudeSub?.cancel();
    if (widget.amplitudeStream != null) {
      _amplitudeSub = widget.amplitudeStream!.listen(
        (amp) {
          if (mounted) {
            _currentAmplitude = amp.clamp(0.0, 1.0);
          }
        },
        onError: (_) {
          if (mounted) _currentAmplitude = 0.0;
        },
      );
    }
  }

  @override
  void didUpdateWidget(covariant AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudeStream != widget.amplitudeStream) {
      _subscribeToStream();
    }
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _animController.removeListener(_onTick);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIdleColor =
        widget.idleColor ?? widget.activeColor.withValues(alpha: 0.35);

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final phase = _animController.value * 2 * math.pi;
        final center = (widget.barCount - 1) / 2.0;

        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (index) {
              // Bell curve weight (center bars naturally peak higher)
              final distFromCenter =
                  (index - center).abs() / (center == 0 ? 1 : center);
              final bellWeight = 1.0 - (distFromCenter * 0.4);

              // Idle subtle oscillation
              final barPhase = phase + (index * 0.65);
              final idleWave = widget.isRecording
                  ? (0.18 + 0.12 * math.sin(barPhase))
                  : 0.12;

              // Voice amplitude bounce with non-linear boost
              final boostedAmp =
                  math.min(1.0, math.sqrt(_smoothedAmplitude) * 1.6);
              final reactiveBounce = boostedAmp * bellWeight * 0.75;

              final totalFraction =
                  (idleWave + reactiveBounce).clamp(0.10, 1.0);
              final barHeight = widget.height * totalFraction;

              final isActive = _smoothedAmplitude > 0.03;
              final barColor = isActive ? widget.activeColor : effectiveIdleColor;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.barSpacing / 2.0,
                ),
                child: Container(
                  width: widget.barWidth,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius:
                        BorderRadius.circular(widget.barWidth / 2.0),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: widget.activeColor.withValues(alpha: 0.45),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
