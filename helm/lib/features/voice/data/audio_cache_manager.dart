// lib/features/voice/data/audio_cache_manager.dart

import 'dart:io';

class AudioCacheManager {
  final Directory _cacheDir;

  AudioCacheManager({Directory? baseDir})
      : _cacheDir = Directory('${(baseDir ?? Directory.systemTemp).path}/waypoint_audio_cache');

  Directory get cacheDirectory => _cacheDir;

  Future<void> _ensureCacheDir() async {
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
  }

  Future<File> createChunk(String sessionId, int index, List<int> bytes) async {
    await _ensureCacheDir();
    final filePath = '${_cacheDir.path}/chunk_${sessionId}_$index.m4a';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<List<File>> getChunksForSession(String sessionId) async {
    if (!await _cacheDir.exists()) return [];

    final prefix = 'chunk_${sessionId}_';
    final entities = await _cacheDir.list().toList();
    final files = entities.whereType<File>().where((file) {
      final name = file.uri.pathSegments.last;
      return name.startsWith(prefix) && name.endsWith('.m4a');
    }).toList();

    // Sort by chunk index numerically
    files.sort((a, b) {
      final idxA = _extractIndex(a.uri.pathSegments.last);
      final idxB = _extractIndex(b.uri.pathSegments.last);
      return idxA.compareTo(idxB);
    });

    return files;
  }

  int _extractIndex(String filename) {
    try {
      final parts = filename.replaceAll('.m4a', '').split('_');
      return int.parse(parts.last);
    } catch (_) {
      return 0;
    }
  }

  Future<void> purgeSession(String sessionId) async {
    final chunks = await getChunksForSession(sessionId);
    for (final chunk in chunks) {
      if (await chunk.exists()) {
        await chunk.delete();
      }
    }
  }

  Future<void> purgeAll() async {
    if (await _cacheDir.exists()) {
      await _cacheDir.delete(recursive: true);
    }
  }
}

