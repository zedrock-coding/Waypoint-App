import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/services/audio_recording_service.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel('com.llfbandit.record/messages');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'create') return 'mock_recorder_id';
      if (methodCall.method == 'dispose') return null;
      if (methodCall.method == 'stop') return null;
      if (methodCall.method == 'hasPermission') return true;
      return null;
    });
  });

  group('AudioRecordingService RMS amplitude tests', () {
    test('calculateRms returns 0.0 for empty or single byte buffer', () {
      expect(AudioRecordingService.calculateRms(Uint8List(0)), equals(0.0));
      expect(AudioRecordingService.calculateRms(Uint8List(1)), equals(0.0));
    });

    test('calculateRms returns 0.0 for pure silence (all zero PCM)', () {
      // 100 16-bit zero samples (200 bytes)
      final silence = Uint8List(200);
      expect(AudioRecordingService.calculateRms(silence), equals(0.0));
    });

    test('calculateRms returns close to 1.0 for full-scale 16-bit PCM', () {
      final buffer = Uint8List(200);
      final byteData = ByteData.sublistView(buffer);
      for (int i = 0; i < 100; i++) {
        byteData.setInt16(i * 2, 32767, Endian.little);
      }

      final rms = AudioRecordingService.calculateRms(buffer);
      expect(rms, greaterThanOrEqualTo(0.99));
      expect(rms, lessThanOrEqualTo(1.0));
    });

    test('calculateRms returns ~0.5 for half-scale 16-bit PCM', () {
      final buffer = Uint8List(200);
      final byteData = ByteData.sublistView(buffer);
      for (int i = 0; i < 100; i++) {
        byteData.setInt16(i * 2, 16384, Endian.little);
      }

      final rms = AudioRecordingService.calculateRms(buffer);
      expect(rms, closeTo(0.5, 0.01));
    });

    test('calculateRms correctly handles alternating positive and negative values', () {
      final buffer = Uint8List(200);
      final byteData = ByteData.sublistView(buffer);
      for (int i = 0; i < 100; i++) {
        final sample = i.isEven ? 10000 : -10000;
        byteData.setInt16(i * 2, sample, Endian.little);
      }

      final rms = AudioRecordingService.calculateRms(buffer);
      // Expected RMS: 10000 / 32768.0 ~ 0.305
      expect(rms, closeTo(10000 / 32768.0, 0.01));
    });

    test('Service exposes broadcast amplitude and duration streams', () {
      final service = AudioRecordingService();
      expect(service.amplitudeStream.isBroadcast, isTrue);
      expect(service.durationStream.isBroadcast, isTrue);
      expect(service.isRecording, isFalse);
      expect(AudioRecordingService.maxRecordingDuration, equals(const Duration(seconds: 30)));
      service.dispose();
    });

    test('stopRecording returns null when nothing was recorded and is idempotent', () async {
      final service = AudioRecordingService();
      final res1 = await service.stopRecording();
      final res2 = await service.stopRecording();
      expect(res1, isNull);
      expect(res2, isNull);
      service.dispose();
    });
  });
}
