import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _streamSub;
  final List<int> _audioBuffer = [];
  bool _isRecording = false;

  bool get isRecording => _isRecording;

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

      _audioBuffer.clear();
      _isRecording = true;

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
        },
        onError: (err) {
          debugPrint('Audio recording stream error: $err');
          _isRecording = false;
        },
        onDone: () {
          _isRecording = false;
        },
      );

      return true;
    } catch (e) {
      debugPrint('Failed to start audio recording: $e');
      _isRecording = false;
      return false;
    }
  }

  Future<Uint8List?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      await _recorder.stop();
      await _streamSub?.cancel();
      _streamSub = null;
      _isRecording = false;

      if (_audioBuffer.isEmpty) {
        return null;
      }

      // Wrap raw PCM 16-bit 16kHz mono in standard WAV header for Gemini audio API
      final wavBytes = _pcmToWav(
        Uint8List.fromList(_audioBuffer),
        sampleRate: 16000,
        channels: 1,
      );

      return wavBytes;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      _isRecording = false;
      return null;
    }
  }

  void cancelRecording() async {
    try {
      await _recorder.cancel();
      await _streamSub?.cancel();
      _streamSub = null;
      _audioBuffer.clear();
      _isRecording = false;
    } catch (e) {
      debugPrint('Error cancelling audio recording: $e');
    }
  }

  void dispose() {
    _streamSub?.cancel();
    _recorder.dispose();
  }

  /// Encodes raw PCM 16-bit audio into a standard RIFF/WAV format
  Uint8List _pcmToWav(Uint8List pcmData, {required int sampleRate, required int channels}) {
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
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // 'fmt ' sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size for PCM
    header.setUint16(20, 1, Endian.little);  // AudioFormat (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, channels * 2, Endian.little); // BlockAlign
    header.setUint16(34, 16, Endian.little);           // BitsPerSample

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
