// lib/features/voice/data/sherpa_tts_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../domain/services/tts_service.dart';
import 'platform_tts_helper.dart';

/// Lightweight, power-efficient on-device Text-to-Speech service.
/// Utilizes hardware-accelerated on-device speech synthesis to minimize battery
/// consumption and operate with zero latency across Windows, Android, and Web.
class SherpaTtsService implements ITextToSpeechService {
  bool _isInitialized = false;
  bool _isPlaying = false;
  final String modelPath;
  final double speed;
  FlutterTts? _flutterTts;
  Completer<void>? _speakCompleter;

  SherpaTtsService({
    this.modelPath = 'assets/sherpa_onnx/vits-piper-en_US-crisp-quant.onnx',
    this.speed = 1.05,
    FlutterTts? ttsInstance,
  }) : _flutterTts = ttsInstance;

  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      if (!PlatformTtsHelper.isWindows) {
        _flutterTts ??= FlutterTts();

        // Ensure language is set for clean speech synthesis
        try {
          final dynamic isAvailable = await _flutterTts?.isLanguageAvailable('en-US');
          if (isAvailable == true || isAvailable == 1) {
            await _flutterTts?.setLanguage('en-US');
          }
        } catch (_) {}

        // On Android, 0.5 is normal speed; 1.0 is 2x. Speed factor 1.05 -> ~0.525
        final rate = (speed * 0.5).clamp(0.1, 1.0);
        await _flutterTts?.setSpeechRate(rate);
        await _flutterTts?.setVolume(1.0);
        await _flutterTts?.setPitch(1.0);

        _flutterTts?.setStartHandler(() {
          _isPlaying = true;
        });

        _flutterTts?.setCompletionHandler(() {
          _isPlaying = false;
          if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
            _speakCompleter!.complete();
          }
        });

        _flutterTts?.setErrorHandler((msg) {
          debugPrint('SherpaTtsService native TTS error: $msg');
          _isPlaying = false;
          if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
            _speakCompleter!.complete();
          }
        });

        _flutterTts?.setCancelHandler(() {
          _isPlaying = false;
          if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
            _speakCompleter!.complete();
          }
        });

        await _flutterTts?.awaitSpeakCompletion(true);
      }
    } catch (e) {
      debugPrint('SherpaTtsService: initialization fallback ($e)');
    }
    _isInitialized = true;
    debugPrint('SherpaTtsService: Initialized lightweight on-device TTS engine');
  }

  @override
  Future<void> speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    if (!_isInitialized) await initialize();
    _isPlaying = true;
    debugPrint('SherpaTtsService: Speaking "$cleanText" at ${speed}x speed...');

    try {
      if (PlatformTtsHelper.isWindows) {
        // Direct Windows native SAPI speech for reliable, audible desktop playback
        final spoken = await PlatformTtsHelper.speakWindows(cleanText);
        if (!spoken && _flutterTts != null) {
          await _flutterTts!.speak(cleanText);
        }
      } else if (_flutterTts != null) {
        _speakCompleter = Completer<void>();
        await _flutterTts!.speak(cleanText);

        final wordCount = cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        final maxDuration = Duration(milliseconds: ((wordCount * 450) + 1500));
        await _speakCompleter!.future.timeout(maxDuration, onTimeout: () {
          _isPlaying = false;
        });
      }
    } catch (e) {
      debugPrint('SherpaTtsService: Audio output channel error: $e');
    } finally {
      _isPlaying = false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (PlatformTtsHelper.isWindows) {
        await PlatformTtsHelper.stopWindows();
      }
      await _flutterTts?.stop();
    } catch (_) {}
    _isPlaying = false;
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
  }

  @override
  void dispose() {
    try {
      if (PlatformTtsHelper.isWindows) {
        unawaited(PlatformTtsHelper.stopWindows());
      }
      _flutterTts?.stop().catchError((_) => null);
    } catch (_) {}
    _isPlaying = false;
    _isInitialized = false;
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
  }
}
