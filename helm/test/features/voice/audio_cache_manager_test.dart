// test/features/voice/audio_cache_manager_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waypoint/features/voice/data/audio_cache_manager.dart';

void main() {
  group('AudioCacheManager Tests', () {
    late Directory tempDir;
    late AudioCacheManager cacheManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('waypoint_cache_test_');
      cacheManager = AudioCacheManager(baseDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Cache retains audio chunks during missing_fields cycle', () async {
      const sessionId = 'session_xyz';
      final chunk1 = await cacheManager.createChunk(sessionId, 0, [0, 1, 2]);
      final chunk2 = await cacheManager.createChunk(sessionId, 1, [3, 4, 5]);

      expect(await chunk1.exists(), true);
      expect(await chunk2.exists(), true);

      final chunks = await cacheManager.getChunksForSession(sessionId);
      expect(chunks.length, 2);
    });

    test('Purge deletes all physical chunk files for completed session', () async {
      const sessionId = 'session_xyz';
      await cacheManager.createChunk(sessionId, 0, [0, 1, 2]);
      await cacheManager.createChunk(sessionId, 1, [3, 4, 5]);

      await cacheManager.purgeSession(sessionId);

      final chunks = await cacheManager.getChunksForSession(sessionId);
      expect(chunks.isEmpty, true);
    });
  });
}

