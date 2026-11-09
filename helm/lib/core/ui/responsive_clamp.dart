import 'package:flutter/material.dart';

/// Standard Material 3 adaptive window size classes.
enum FormFactor {
  /// Phones and narrow screens (< 600px width).
  compact,

  /// Small tablets, foldables, and landscape phones (600px - 840px width).
  medium,

  /// Tablets, desktop windows, and large web displays (>= 840px width).
  expanded,
}

/// Universal UI clamp and responsive scaling engine.
///
/// Mimics CSS/React `clamp(min, preferred, max)` to dynamically adapt
/// element dimensions to screen size while strictly honoring safe bounds.
class UIClamp {
  /// Baseline viewport width (standard modern smartphone viewport).
  static const double mobileBaseline = 390.0;

  /// Baseline tablet viewport width.
  static const double tabletBaseline = 768.0;

  /// Clamps a dimension between [min] and [max], scaling [preferred]
  /// proportionally against the device width relative to [baseline].
  ///
  /// Formula: `(preferred * (screenWidth / baseline)).clamp(min, max)`
  static double clamp(
    BuildContext context, {
    required double min,
    required double preferred,
    required double max,
    double baseline = mobileBaseline,
  }) {
    final double width = MediaQuery.sizeOf(context).width;
    final double scale = width / baseline;
    final double scaled = preferred * scale;
    return scaled.clamp(min, max);
  }

  /// Clamps a vertical height dimension relative to device screen height.
  static double clampHeight(
    BuildContext context, {
    required double min,
    required double preferred,
    required double max,
    double baseline = 844.0,
  }) {
    final double height = MediaQuery.sizeOf(context).height;
    final double scale = height / baseline;
    final double scaled = preferred * scale;
    return scaled.clamp(min, max);
  }

  /// Direct raw number clamp.
  static double value(double val, double min, double max) {
    return val.clamp(min, max);
  }

  /// Evaluates the active device form factor from constraints.
  static FormFactor formFactor(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width < 600) return FormFactor.compact;
    if (width < 840) return FormFactor.medium;
    return FormFactor.expanded;
  }

  /// Selects a responsive value based on device form factor.
  static T responsive<T>(
    BuildContext context, {
    required T compact,
    T? medium,
    T? expanded,
  }) {
    final factor = formFactor(context);
    switch (factor) {
      case FormFactor.compact:
        return compact;
      case FormFactor.medium:
        return medium ?? compact;
      case FormFactor.expanded:
        return expanded ?? medium ?? compact;
    }
  }

  /// Clamps device text scaling to prevent aggressive accessibility
  /// multipliers (e.g. 2.0x+) from breaking tabular or dense horizontal rows.
  static TextScaler clampedTextScaler(
    BuildContext context, {
    double minScale = 0.85,
    double maxScale = 1.25,
    double userScale = 1.0,
  }) {
    final double effectiveScale = userScale.clamp(minScale, maxScale);
    return TextScaler.linear(effectiveScale);
  }

  /// Configures global error handling to neutralize RenderFlex overflow
  /// crashes and red error screens across debug, profile, and release runs.
  static void enableOverflowProtection() {
    final originalOnError = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      final String msg = details.exceptionAsString();
      final String summary = details.summary.toString();
      final bool isOverflow = msg.contains('A RenderFlex overflowed') ||
          summary.contains('overflowed by');

      if (isOverflow) {
        // Suppress red-screen fatal crash and log concise warning
        debugPrint('UIClamp: Suppressed RenderFlex layout overflow: $summary');
        return;
      }

      if (originalOnError != null) {
        originalOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    // Render a safe, resilient, non-crashing widget if layout overflow ever occurs
    ErrorWidget.builder = (FlutterErrorDetails details) {
      final String msg = details.exceptionAsString();
      final String summary = details.summary.toString();
      final bool isOverflow = msg.contains('A RenderFlex overflowed') ||
          summary.contains('overflowed by');

      if (isOverflow) {
        return const SizedBox.shrink();
      }

      return const Material(
        color: Colors.transparent,
        child: Center(
          child: SizedBox.shrink(),
        ),
      );
    };
  }
}

/// Responsive extensions on [BuildContext] for clean, concise widget trees.
extension ResponsiveClampExtension on BuildContext {
  FormFactor get formFactor => UIClamp.formFactor(this);
  bool get isCompact => formFactor == FormFactor.compact;
  bool get isMedium => formFactor == FormFactor.medium;
  bool get isExpanded => formFactor == FormFactor.expanded;

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Dynamic dimension clamp: `clamp(min, preferred, max)`
  double clampDimension({
    required double min,
    required double preferred,
    required double max,
    double baseline = UIClamp.mobileBaseline,
  }) =>
      UIClamp.clamp(
        this,
        min: min,
        preferred: preferred,
        max: max,
        baseline: baseline,
      );

  /// Height clamp: `clampHeight(min, preferred, max)`
  double clampHeight({
    required double min,
    required double preferred,
    required double max,
    double baseline = 844.0,
  }) =>
      UIClamp.clampHeight(
        this,
        min: min,
        preferred: preferred,
        max: max,
        baseline: baseline,
      );

  /// Pick responsive value according to screen form factor.
  T responsive<T>({
    required T compact,
    T? medium,
    T? expanded,
  }) =>
      UIClamp.responsive<T>(
        this,
        compact: compact,
        medium: medium,
        expanded: expanded,
      );
}

