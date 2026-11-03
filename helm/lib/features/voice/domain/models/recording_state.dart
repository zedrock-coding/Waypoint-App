// lib/features/voice/domain/models/recording_state.dart

class RecordingState {
  final Duration elapsed;
  final Duration remaining;
  final double normalizedAmplitude;
  final List<double> amplitudeHistory;
  final bool isRecording;
  final bool isLimitReached;

  const RecordingState({
    required this.elapsed,
    required this.remaining,
    required this.normalizedAmplitude,
    required this.amplitudeHistory,
    required this.isRecording,
    required this.isLimitReached,
  });

  factory RecordingState.initial() => const RecordingState(
        elapsed: Duration.zero,
        remaining: Duration(seconds: 30),
        normalizedAmplitude: 0.0,
        amplitudeHistory: [],
        isRecording: false,
        isLimitReached: false,
      );

  RecordingState copyWith({
    Duration? elapsed,
    Duration? remaining,
    double? normalizedAmplitude,
    List<double>? amplitudeHistory,
    bool? isRecording,
    bool? isLimitReached,
  }) {
    return RecordingState(
      elapsed: elapsed ?? this.elapsed,
      remaining: remaining ?? this.remaining,
      normalizedAmplitude: normalizedAmplitude ?? this.normalizedAmplitude,
      amplitudeHistory: amplitudeHistory ?? this.amplitudeHistory,
      isRecording: isRecording ?? this.isRecording,
      isLimitReached: isLimitReached ?? this.isLimitReached,
    );
  }
}

