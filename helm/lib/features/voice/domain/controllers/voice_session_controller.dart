// lib/features/voice/domain/controllers/voice_session_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../task/domain/models/extracted_task_result.dart';
import '../../../task/domain/services/task_extraction_parser.dart';
import '../../data/audio_cache_manager.dart';
import '../../data/sherpa_tts_service.dart';
import '../services/tts_service.dart';

enum VoiceSessionStatus {
  idle,
  userListening,
  processing,
  agentSpeaking,
  completed,
  error,
  // Backwards compatibility aliases
  listening,
  speakingDisambiguation,
  taskCreated,
}

enum VoiceSessionState {
  idle,
  listening,
  processing,
  speakingDisambiguation,
  agentSpeaking,
  taskCreated,
  completed,
  error,
}

class VoiceSessionController extends ChangeNotifier {
  final TaskExtractionParser _parser;
  final ITextToSpeechService _ttsService;
  final AudioCacheManager? _cacheManager;
  final String sessionId;
  final Duration watchdogDuration;

  VoiceSessionStatus _status = VoiceSessionStatus.idle;
  VoiceSessionState _state = VoiceSessionState.idle;
  Duration _remaining = const Duration(seconds: 30);
  Timer? _countdownTimer;
  Timer? _watchdogTimer;
  final Stopwatch _stopwatch = Stopwatch();

  String _accumulatedTranscript = '';
  final List<Map<String, String>> _conversationHistory = [];
  int _currentChunkIndex = 0;
  ExtractedTaskResult? _currentTaskResult;
  String? _lastQuestion;
  String? _confirmationMessage;
  bool _watchdogFired = false;

  VoiceSessionController({
    TaskExtractionParser? parser,
    ITextToSpeechService? ttsService,
    AudioCacheManager? cacheManager,
    String? sessionId,
    this.watchdogDuration = const Duration(seconds: 4),
  })  : _parser = parser ?? TaskExtractionParser(),
        _ttsService = ttsService ?? SherpaTtsService(),
        _cacheManager = cacheManager,
        sessionId =
            sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}';

  VoiceSessionStatus get status => _status;
  VoiceSessionState get state => _state;
  Duration get remaining => _remaining;
  bool get isListening =>
      _state == VoiceSessionState.listening ||
      _status == VoiceSessionStatus.userListening ||
      _status == VoiceSessionStatus.listening;
  bool get isSpeakingDisambiguation =>
      _state == VoiceSessionState.speakingDisambiguation ||
      _state == VoiceSessionState.agentSpeaking ||
      _status == VoiceSessionStatus.agentSpeaking ||
      _status == VoiceSessionStatus.speakingDisambiguation;
  bool get isTaskCreated =>
      _state == VoiceSessionState.taskCreated ||
      _state == VoiceSessionState.completed ||
      _status == VoiceSessionStatus.taskCreated ||
      _status == VoiceSessionStatus.completed;
  bool get watchdogFired => _watchdogFired;

  ExtractedTaskResult? get currentTaskResult => _currentTaskResult;
  String get accumulatedTranscript => _accumulatedTranscript;
  List<Map<String, String>> get conversationHistory => List.unmodifiable(_conversationHistory);
  int get currentChunkIndex => _currentChunkIndex;
  String? get lastQuestion => _lastQuestion;
  String? get confirmationMessage => _confirmationMessage;
  ITextToSpeechService get ttsService => _ttsService;

  void startCall() {
    _accumulatedTranscript = '';
    _conversationHistory.clear();
    _currentChunkIndex = 0;
    _currentTaskResult = null;
    _lastQuestion = null;
    _confirmationMessage = null;
    _watchdogFired = false;
    _startListeningTurn();
  }

  void _startListeningTurn() {
    _status = VoiceSessionStatus.userListening;
    _state = VoiceSessionState.listening;
    _remaining = const Duration(seconds: 30);
    _stopwatch.reset();
    _stopwatch.start();
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final elapsed = _stopwatch.elapsed;
      _remaining = const Duration(seconds: 30) - elapsed;

      if (_remaining <= Duration.zero) {
        _remaining = Duration.zero;
        timer.cancel();
        _stopwatch.stop();
        completeUserSpeechTurn();
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> completeUserSpeechTurn() async {
    _countdownTimer?.cancel();
    _stopwatch.stop();
    _status = VoiceSessionStatus.processing;
    _state = VoiceSessionState.processing;
    notifyListeners();
  }

  Future<void> processUserInput(String input, {List<int>? audioBytes}) async {
    _countdownTimer?.cancel();
    _stopwatch.stop();
    _status = VoiceSessionStatus.processing;
    _state = VoiceSessionState.processing;
    notifyListeners();

    final cleanInput = input.trim();
    if (_accumulatedTranscript.isEmpty) {
      _accumulatedTranscript = cleanInput;
    } else {
      _accumulatedTranscript = '$_accumulatedTranscript $cleanInput';
    }

    _conversationHistory.add({'role': 'user', 'content': cleanInput});

    final newResult = _parser.parse(_accumulatedTranscript);
    if (_currentTaskResult != null &&
        _currentTaskResult!.title.isNotEmpty &&
        _currentTaskResult!.title != 'New Task') {
      _currentTaskResult = ExtractedTaskResult(
        title: _currentTaskResult!.title,
        description: _currentTaskResult!.description.isNotEmpty
            ? _currentTaskResult!.description
            : newResult.description,
        dueDate: newResult.dueDate ?? _currentTaskResult!.dueDate,
        priority: (newResult.priority.isNotEmpty && newResult.priority != 'medium')
            ? newResult.priority
            : _currentTaskResult!.priority,
        subtasks: _currentTaskResult!.subtasks.isNotEmpty
            ? _currentTaskResult!.subtasks
            : newResult.subtasks,
        missingFields: newResult.missingFields,
        disambiguationPrompt: newResult.disambiguationPrompt,
      );
    } else {
      _currentTaskResult = newResult;
    }

    if (_currentTaskResult!.missingFields.isNotEmpty) {
      final question = _currentTaskResult!.disambiguationPrompt ??
          'When would you like this scheduled?';
      _lastQuestion = question;
      _conversationHistory.add({'role': 'assistant', 'content': question});
      _status = VoiceSessionStatus.agentSpeaking;
      _state = VoiceSessionState.speakingDisambiguation;
      notifyListeners();

      if (audioBytes != null && _cacheManager != null) {
        await _cacheManager.createChunk(sessionId, _currentChunkIndex, audioBytes);
      }

      _currentChunkIndex++;

      // Arm emergency watchdog failsafe timer dynamically scaled to question length
      _armWatchdogTimer(question);

      try {
        await _ttsService.speak(question);
      } catch (e) {
        debugPrint('VoiceSessionController: TTS synthesis error: $e');
      } finally {
        _watchdogTimer?.cancel();
        // Hardware settle delay between speaker finish and microphone opening
        await Future.delayed(const Duration(milliseconds: 300));
        onTtsCompleted();
      }
    } else {
      final title = _currentTaskResult!.title;
      final timeStr = _currentTaskResult!.dueDate != null
          ? _formatTime(_currentTaskResult!.dueDate!)
          : 'soon';
      _confirmationMessage = 'Created task: $title for $timeStr';
      _conversationHistory.add({'role': 'assistant', 'content': _confirmationMessage!});
      _status = VoiceSessionStatus.taskCreated;
      _state = VoiceSessionState.taskCreated;
      notifyListeners();

      if (audioBytes != null && _cacheManager != null) {
        await _cacheManager.createChunk(sessionId, _currentChunkIndex, audioBytes);
      }
      if (_cacheManager != null) {
        await _cacheManager.purgeSession(sessionId);
      }

      try {
        await _ttsService.speak(_confirmationMessage!);
      } catch (_) {}

      _status = VoiceSessionStatus.completed;
      _state = VoiceSessionState.completed;
      notifyListeners();
    }
  }

  void _armWatchdogTimer([String? text]) {
    _watchdogTimer?.cancel();
    final effectiveTimeout = text != null
        ? Duration(milliseconds: 7000 + (text.length * 80))
        : watchdogDuration;
    _watchdogTimer = Timer(effectiveTimeout, () {
      if (_status == VoiceSessionStatus.agentSpeaking ||
          _status == VoiceSessionStatus.speakingDisambiguation ||
          _state == VoiceSessionState.speakingDisambiguation) {
        debugPrint(
            'VoiceSessionController: Watchdog safety timer triggered: TTS playback did not complete in ${effectiveTimeout.inSeconds}s. Recovering...');
        _watchdogFired = true;
        _ttsService.stop();
        onTtsCompleted();
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  void onTtsCompleted() {
    _watchdogTimer?.cancel();
    if (_state == VoiceSessionState.speakingDisambiguation ||
        _status == VoiceSessionStatus.speakingDisambiguation ||
        _status == VoiceSessionStatus.agentSpeaking) {
      _startListeningTurn();
    }
  }

  void playAgentResponse(String ttsAudioPath, {required bool isDisambiguation}) {
    if (isDisambiguation) {
      _status = VoiceSessionStatus.userListening;
      _state = VoiceSessionState.listening;
      _startListeningTurn();
    } else {
      _status = VoiceSessionStatus.completed;
      _state = VoiceSessionState.completed;
      notifyListeners();
    }
  }

  void endCall() {
    _countdownTimer?.cancel();
    _watchdogTimer?.cancel();
    _stopwatch.stop();
    _status = VoiceSessionStatus.idle;
    _state = VoiceSessionState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _watchdogTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
