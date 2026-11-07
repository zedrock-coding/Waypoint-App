// test/features/voice/tts_asset_staging_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/voice/data/sherpa_model_asset_manager.dart';
import 'package:waypoint/features/voice/data/sherpa_tts_service.dart';
import 'package:waypoint/features/voice/data/wav_audio_container_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Test Suite 1: TTS Asset Staging & Output Integrity', () {
    late Directory tempDir;
    late SherpaModelAssetManager assetManager;
    late SherpaTtsService ttsService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sherpa_test_');
      assetManager = SherpaModelAssetManager();
      assetManager.reset();
      ttsService = SherpaTtsService(assetManager: assetManager);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'Scenario A: Verify model and tokens files are physically present with non-zero byte lengths after staging initialization',
        () async {
      final staged = await assetManager.stageAssets(targetDirectory: tempDir);
      expect(staged, isTrue);
      expect(assetManager.isStaged, isTrue);

      final modelPath = assetManager.modelAbsolutePath;
      final tokensPath = assetManager.tokensAbsolutePath;

      expect(modelPath, isNotNull);
      expect(tokensPath, isNotNull);

      final modelFile = File(modelPath!);
      final tokensFile = File(tokensPath!);

      expect(modelFile.existsSync(), isTrue);
      expect(modelFile.lengthSync(), greaterThan(0));

      expect(tokensFile.existsSync(), isTrue);
      expect(tokensFile.lengthSync(), greaterThan(0));
    });

    test(
        'Scenario B: Synthesize sample text and verify output file exists, is non-empty, and has valid 44-byte RIFF/WAV header',
        () async {
      const sampleText = 'When is this task due, and what is its priority?';
      final outputPath = '${tempDir.path}/test_output.wav';

      final wavFile = await ttsService.synthesizeToWavFile(
        sampleText,
        outputPath: outputPath,
      );

      expect(wavFile.existsSync(), isTrue);
      expect(wavFile.lengthSync(), greaterThan(44));

      final bytes = await wavFile.readAsBytes();
      final isValidWav = WavAudioContainerUtil.isValidWavHeader(bytes);
      expect(isValidWav, isTrue);

      // Verify RIFF signature
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      // Verify WAVE signature
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      // Verify fmt signature
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      // Verify data signature
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    });
  });
}

