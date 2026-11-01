import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _streamSub;
  final List<int> _audioBuffer = [];
  bool _isRecording = false;

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  Timer? _durationTimer;
  DateTime? _recordStartTime;
  Uint8List? _lastRecordedWav;
  Future<Uint8List?>? _stoppingFuture;

  /// Maximum recording time enforced for safety and API payload limits.
  static const Duration maxRecordingDuration = Duration(seconds: 30);

  /// Callback fired when recording reaches [maxRecordingDuration].
  VoidCallback? onTimeout;

  bool get isRecording => _isRecording;
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  /// Computes Root-Mean-Square (RMS) amplitude from 16-bit signed PCM audio bytes.
  /// Returns a normalized value between 0.0 and 1.0.
  static double calculateRms(Uint8List chunk) {
    if (chunk.length < 2) return 0.0;
    final byteData = ByteData.sublistView(chunk);
    final sampleCount = chunk.length ~/ 2;
    if (sampleCount == 0) return 0.0;

    double sumSquares = 0.0;
    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      sumSquares += sample * sample;
    }
    final rms = math.sqrt(sumSquares / sampleCount);
    // 32768.0 is full-scale maximum peak for 16-bit PCM
    return (rms / 32768.0).clamp(0.0, 1.0);
  }

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('AudioRecordingService permission check error: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    try {
      final permitted = await hasPermission();
      if (!permitted) {
        debugPrint('Audio recording permission denied');
        return false;
      }

      if (_isRecording) {
        await stopRecording();
      }

      _lastRecordedWav = null;
      _audioBuffer.clear();
      _isRecording = true;
      _recordStartTime = DateTime.now();
      _durationController.add(Duration.zero);

      _stopDurationTimer();
      _durationTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (!_isRecording || _recordStartTime == null) {
          timer.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(_recordStartTime!);
        if (elapsed >= maxRecordingDuration) {
          _durationController.add(maxRecordingDuration);
          timer.cancel();
          _stopDurationTimer();
          if (onTimeout != null) {
            onTimeout!();
          } else {
            stopRecording();
          }
        } else {
          _durationController.add(elapsed);
        }
      });

      // Use 16kHz mono WAV/PCM suitable for Gemini and edge ASR
      final recordStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _streamSub = recordStream.listen(
        (chunk) {
          _audioBuffer.addAll(chunk);
          final amp = calculateRms(chunk);
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(amp);
          }
        },
        onError: (err) {
          debugPrint('Audio recording stream error: $err');
          _stopDurationTimer();
          _isRecording = false;
        },
        onDone: () {
          _stopDurationTimer();
          _isRecording = false;
        },
      );

      return true;
    } catch (e) {
      debugPrint('Failed to start audio recording: $e');
      _stopDurationTimer();
      _isRecording = false;
      return false;
    }
  }

  Future<Uint8List?> stopRecording() async {
    if (_stoppingFuture != null) {
      return await _stoppingFuture;
    }
    if (!_isRecording) {
      return _lastRecordedWav;
    }
    _stoppingFuture = _executeStopRecording();
    try {
      return await _stoppingFuture;
    } finally {
      _stoppingFuture = null;
    }
  }

  Future<Uint8List?> _executeStopRecording() async {
    try {
      _stopDurationTimer();
      if (!_amplitudeController.isClosed) {
        _amplitudeController.add(0.0);
      }
      await _recorder.stop();
      await _streamSub?.cancel();
      _streamSub = null;
      _isRecording = false;

      if (_audioBuffer.isEmpty) {
        _lastRecordedWav = null;
        return null;
      }

      // Wrap raw PCM 16-bit 16kHz mono in standard WAV header for Gemini audio API
      final wavBytes = _pcmToWav(
        Uint8List.fromList(_audioBuffer),
        sampleRate: 16000,
        channels: 1,
      );

      _lastRecordedWav = wavBytes;
      return wavBytes;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _stopDurationTimer();
      _isRecording = false;
      _lastRecordedWav = null;
      return null;
    }
  }

  void cancelRecording() async {
    try {
      _stopDurationTimer();
      if (!_amplitudeController.isClosed) {
        _amplitudeController.add(0.0);
      }
      await _recorder.cancel();
      await _streamSub?.cancel();
      _streamSub = null;
      _audioBuffer.clear();
      _lastRecordedWav = null;
      _isRecording = false;
    } catch (e) {
      debugPrint('Error cancelling audio recording: $e');
    }
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _recordStartTime = null;
  }

  void dispose() {
    _stopDurationTimer();
    _amplitudeController.close();
    _durationController.close();
    _streamSub?.cancel();
    _recorder.dispose();
  }

  /// Encodes raw PCM 16-bit audio into a standard RIFF/WAV format
  Uint8List _pcmToWav(
    Uint8List pcmData, {
    required int sampleRate,
    required int channels,
  }) {
    final byteRate = sampleRate * channels * 2;
    final totalDataLen = pcmData.length;
    final totalAudioLen = totalDataLen + 36;

    final header = ByteData(44);
    // RIFF chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, totalAudioLen, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // 'fmt ' sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size for PCM
    header.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * 2, Endian.little); // BlockAlign
    header.setUint16(34, 16, Endian.little); // BitsPerSample

    // 'data' sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, totalDataLen, Endian.little);

    final wav = Uint8List(44 + totalDataLen);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + totalDataLen, pcmData);
    return wav;
  }
}
