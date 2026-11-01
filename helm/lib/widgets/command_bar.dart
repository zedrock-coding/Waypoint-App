import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_service.dart';
import '../services/audio_recording_service.dart';
import '../services/supabase_service.dart';
import '../providers/task_provider.dart';
import '../models/unified_task.dart';
import 'app_snackbar.dart';
import 'audio_waveform_visualizer.dart';

class CommandBarWidget extends StatefulWidget {
  const CommandBarWidget({super.key});

  @override
  State<CommandBarWidget> createState() => _CommandBarWidgetState();
}

class _CommandBarWidgetState extends State<CommandBarWidget>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _stt = stt.SpeechToText();
  final _audioService = AudioRecordingService();
  bool _isListening = false;
  bool _isLoading = false;

  /// True when the current capture is the audio recorder (multimodal path);
  /// false when we fell back to speech-to-text only.
  bool _capturingAudio = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _audioService.onTimeout = () {
      if (mounted && _isListening) {
        _stopAndProcessVoice();
      }
    };
  }

  @override
  void dispose() {
    _glowController.dispose();
    _textController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    try {
      if (_isListening) {
        await _stopAndProcessVoice();
        return;
      }

      // One capture source at a time. Running `record` and `speech_to_text`
      // together meant two consumers fought over the microphone.
      // Prefer the recorder (the AI path takes audio directly).
      _capturingAudio = await _audioService.startRecording();
      if (_capturingAudio) {
        setState(() => _isListening = true);
        return;
      }

      final sttAvailable = await _startSttOnly();
      if (sttAvailable) {
        setState(() => _isListening = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio recording is not available.')),
        );
      }
    } catch (e) {
      debugPrint('Voice toggle error: $e');
      setState(() => _isListening = false);
    }
  }

  Future<bool> _startSttOnly() async {
    try {
      final available = await _stt.initialize(
        onStatus: (status) {
          if (status == 'notListening' && mounted && _isListening) {
            _stopAndProcessVoice();
          }
        },
        onError: (error) => debugPrint('STT Error: $error'),
      );
      if (!available) return false;

      await _stt.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _textController.text = result.recognizedWords);
          }
        },
      );
      return true;
    } catch (e) {
      debugPrint('STT init failed: $e');
      return false;
    }
  }

  Future<void> _stopAndProcessVoice() async {
    if (!_isListening) return;

    setState(() => _isListening = false);

    if (_capturingAudio) {
      _capturingAudio = false;
      final audioBytes = await _audioService.stopRecording();
      if (audioBytes != null && audioBytes.length > 500) {
        // Direct Multimodal audio pipeline
        await _handleVoiceCommand(audioBytes);
        return;
      }
    } else {
      await _stt.stop();
    }

    // Process typed or STT text fallback
    await _handleCommand();
  }

  Future<void> _handleVoiceCommand(Uint8List audioBytes) async {
    setState(() => _isLoading = true);
    final aiService = context.read<AiService>();
    final taskProvider = context.read<TaskProvider>();
    final supabaseService = SupabaseService();

    try {
      final communities = await supabaseService.fetchUserCommunities();
      final members = await supabaseService.fetchAllAccessibleMembers();

      final result = await aiService.parseVoiceCommand(
        audioBytes: audioBytes,
        availableCommunities: communities,
        availableMembers: members,
      );

      await _applyTaskResult(result, taskProvider);
    } catch (e) {
      debugPrint('Voice command processing error: $e');
      // If direct audio fails, fallback to text command
      if (_textController.text.trim().isNotEmpty) {
        await _handleCommand();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI Voice Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCommand() async {
    final input = _textController.text.trim();
    if (input.isEmpty) return;

    if (_isListening) {
      _stt.stop();
      _audioService.cancelRecording();
      setState(() => _isListening = false);
    }

    setState(() => _isLoading = true);
    final aiService = context.read<AiService>();
    final taskProvider = context.read<TaskProvider>();
    final supabaseService = SupabaseService();

    try {
      final communities = await supabaseService.fetchUserCommunities();
      final members = await supabaseService.fetchAllAccessibleMembers();

      // Hybrid parse: local rules for short commands, Gemini for complex tasks.
      final result = await aiService.parseHybridCommand(
        userInput: input,
        availableCommunities: communities,
        availableMembers: members,
      );

      await _applyTaskResult(result, taskProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyTaskResult(
    Map<String, dynamic>? result,
    TaskProvider taskProvider,
  ) async {
    if (result == null) {
      throw Exception('Could not understand task command.');
    }

    final bool clarificationNeeded = result['clarification_needed'] ?? false;
    if (clarificationNeeded) {
      if (mounted) {
        final msg =
            result['clarification_message'] ?? 'Could you clarify what you want to do?';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI: $msg'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final title = result['title'] ?? 'New AI Task';
    final description = result['description'];

    final dueDate = AiService.parseAiDueDate(
      result['due_date'],
      result['due_time'] ?? result['time'],
    );

    final communityId = result['community_id'];
    final assigneeId = result['assignee_id'];
    final Priority priority =
        UnifiedTask.parsePriority(result['priority']?.toString());

    final rawSubtasks = result['subtasks'] as List? ?? [];
    final List<Map<String, dynamic>> subtaskMaps = rawSubtasks
        .asMap()
        .entries
        .map((e) => {
              'id': const Uuid().v4(),
              'title': e.value.toString().trim(),
              'is_completed': false,
              'order': e.key,
            })
        .where((st) => (st['title'] as String).isNotEmpty)
        .toList();

    final createdId = await taskProvider.addTask(
      title: title,
      description: description,
      communityId: communityId,
      assignees: assigneeId != null ? [assigneeId] : [],
      subtasks: subtaskMaps,
      priority: priority,
      status: Status.toDo,
      dueAt: dueDate,
    );

    if (mounted) {
      _textController.clear();
      final subtaskCount = subtaskMaps.length;
      final msg = subtaskCount > 0
          ? 'Task created with $subtaskCount subtask milestone${subtaskCount == 1 ? '' : 's'}!'
          : 'AI Task Created!';

      AppSnackBar.showUndo(
        context: context,
        message: msg,
        onUndo: () => taskProvider.deleteTask(createdId),
        duration: const Duration(seconds: 5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final double glow = _isLoading ? _glowController.value : 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: _isListening
                    ? const Color(0xFF88C0A4).withValues(alpha: 0.25)
                    : colorScheme.primary.withValues(alpha: 0.15 * glow),
                blurRadius: _isListening ? 16 : 10 * glow,
                spreadRadius: _isListening ? 2 : 2 * glow,
              )
            ],
            border: Border.all(
              color: _isListening
                  ? const Color(0xFF88C0A4)
                  : (_isLoading
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.5)),
              width: (_isListening || _isLoading) ? 2 : 1,
            ),
          ),
          child: _isLoading
              ? _buildLoadingPill(colorScheme)
              : (_isListening
                  ? _buildListeningPill(colorScheme)
                  : _buildNormalInput(colorScheme)),
        );
      },
    );
  }

  Widget _buildLoadingPill(ColorScheme colorScheme) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF88C0A4)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'AI is decomposing task & subtasks...',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningPill(ColorScheme colorScheme) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Listening',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF88C0A4),
            ),
          ),
          const SizedBox(width: 12),
          AudioWaveformVisualizer(
            amplitudeStream: _audioService.amplitudeStream,
            barCount: 7,
            height: 22,
            barWidth: 3,
            barSpacing: 3,
            activeColor: const Color(0xFF88C0A4),
          ),
          const Spacer(),
          StreamBuilder<Duration>(
            stream: _audioService.durationStream,
            builder: (context, snapshot) {
              final sec = (snapshot.data?.inSeconds ?? 0).clamp(0, 30);
              final display = '0:${sec.toString().padLeft(2, '0')} / 0:30';
              return Text(
                display,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.white70,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _stopAndProcessVoice,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              backgroundColor: const Color(0xFF88C0A4).withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                color: Color(0xFF88C0A4),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalInput(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              hintText: 'Type or speak a task command...',
              border: InputBorder.none,
              isDense: true,
            ),
            onSubmitted: (_) => _handleCommand(),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.mic_none,
            color: colorScheme.primary,
          ),
          onPressed: _isLoading ? null : _toggleListening,
          tooltip: 'Speak task command',
        ),
        IconButton(
          icon: Icon(
            Icons.send_rounded,
            color: _textController.text.isEmpty ? Colors.grey : colorScheme.primary,
          ),
          onPressed: (_isLoading || _textController.text.isEmpty)
              ? null
              : _handleCommand,
          tooltip: 'Send command',
        ),
      ],
    );
  }
}
