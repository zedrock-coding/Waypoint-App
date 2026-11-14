import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ai_voice_overlay.dart';
import '../features/voice/data/sherpa_tts_service.dart';
import '../features/voice/domain/services/tts_service.dart';
import '../models/hive_models.dart';
import '../services/ai_service.dart';
import '../services/audio_recording_service.dart';
import '../services/debouncer.dart';
import '../services/needle_reconciliation_engine.dart';
import '../providers/task_provider.dart';
import '../models/unified_task.dart';
import '../theme/app_theme.dart';
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
  final ITextToSpeechService _ttsService = SherpaTtsService();
  final _inputDebouncer = Debouncer(milliseconds: 300);

  bool _isListening = false;
  bool _isLoading = false;
  bool _isAiSpeaking = false;

  /// Multimodal conversational session tracking
  Map<String, dynamic>? _currentDraft;
  final List<Map<String, String>> _conversationHistory = [];
  String? _clarificationPrompt;

  /// True when the current capture is the audio recorder (multimodal path);
  /// false when we fell back to speech-to-text only.
  bool _capturingAudio = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    unawaited(_ttsService.initialize());

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
    _inputDebouncer.dispose();
    _glowController.dispose();
    _textController.dispose();
    _audioService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  void _openVoiceOverlay(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 800;
    if (!isDesktop) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => const AIVoiceOverlay(),
      );
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black26,
        builder: (ctx) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: const Dialog(
              backgroundColor: Colors.transparent,
              child: AIVoiceOverlay(),
            ),
          ),
        ),
      );
    }
  }

  void _cancelConversation() {
    _ttsService.stop();
    _audioService.cancelRecording();
    if (mounted) {
      setState(() {
        _isListening = false;
        _isLoading = false;
        _isAiSpeaking = false;
        _currentDraft = null;
        _conversationHistory.clear();
        _clarificationPrompt = null;
      });
    }
  }

  Future<void> _startVoiceCapture() async {
    _capturingAudio = await _audioService.startRecording();
    if (_capturingAudio) {
      if (mounted) setState(() => _isListening = true);
      return;
    }

    final sttAvailable = await _startSttOnly();
    if (sttAvailable) {
      if (mounted) setState(() => _isListening = true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio recording is not available.')),
      );
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
        _conversationHistory.add({'role': 'user', 'content': '[Spoken Voice Command]'});
        // Direct Multimodal audio pipeline
        await _handleVoiceCommand(audioBytes);
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No speech detected. Please speak closer to the microphone.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
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

    try {
      // Read communities & members instantly from embedded Hive cache to eliminate latency
      List<Map<String, dynamic>> communities = [];
      List<Map<String, dynamic>> members = [];
      if (Hive.isBoxOpen('communities')) {
        communities = Hive.box<Community>('communities').values
            .map((c) => {'id': c.id, 'name': c.name})
            .toList();
      }
      if (Hive.isBoxOpen('community_members')) {
        members = Hive.box<CommunityMember>('community_members').values
            .map((m) => {'id': m.userId, 'full_name': m.fullName, 'community_id': m.communityId})
            .toList();
      }

      final result = await aiService.parseVoiceCommand(
        audioBytes: audioBytes,
        availableCommunities: communities,
        availableMembers: members,
        currentDraft: _currentDraft,
        conversationHistory: _conversationHistory,
      );

      final userTranscript = _textController.text.trim().isNotEmpty
          ? _textController.text.trim()
          : (result?['transcript'] ?? result?['title'] ?? '');

      await _applyTaskResult(
        result,
        taskProvider,
        rawTranscript: userTranscript,
        availableMembers: members,
        availableCommunities: communities,
      );
    } catch (e) {
      debugPrint('Voice command processing error: $e');
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
      if (mounted && !_isListening && !_isAiSpeaking) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCommand() async {
    final input = _textController.text.trim();
    if (input.isEmpty) return;

    _conversationHistory.add({'role': 'user', 'content': input});

    if (_isListening) {
      _stt.stop();
      _audioService.cancelRecording();
      setState(() => _isListening = false);
    }

    setState(() => _isLoading = true);
    final aiService = context.read<AiService>();
    final taskProvider = context.read<TaskProvider>();

    try {
      List<Map<String, dynamic>> communities = [];
      List<Map<String, dynamic>> members = [];
      if (Hive.isBoxOpen('communities')) {
        communities = Hive.box<Community>('communities').values
            .map((c) => {'id': c.id, 'name': c.name})
            .toList();
      }
      if (Hive.isBoxOpen('community_members')) {
        members = Hive.box<CommunityMember>('community_members').values
            .map((m) => {'id': m.userId, 'full_name': m.fullName, 'community_id': m.communityId})
            .toList();
      }

      final result = await aiService.parseHybridCommand(
        userInput: input,
        availableCommunities: communities,
        availableMembers: members,
      );

      await _applyTaskResult(
        result,
        taskProvider,
        rawTranscript: input,
        availableMembers: members,
        availableCommunities: communities,
      );
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
      if (mounted && !_isListening && !_isAiSpeaking) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyTaskResult(
    Map<String, dynamic>? result,
    TaskProvider taskProvider, {
    String? rawTranscript,
    List<Map<String, dynamic>> availableMembers = const [],
    List<Map<String, dynamic>> availableCommunities = const [],
  }) async {
    if (result == null) {
      throw Exception('Could not understand task command.');
    }

    final transcript = (rawTranscript ?? result['transcript'] ?? result['title'] ?? '').toString();
    String currentUserId = 'local_user';
    try {
      currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'local_user';
    } catch (_) {}

    final contextHeader = <String, dynamic>{
      'client_timestamp': DateTime.now().toIso8601String(),
      'client_timezone': DateTime.now().timeZoneName,
      'current_user': currentUserId,
      'accessible_members': availableMembers,
      'accessible_communities': availableCommunities,
    };

    final reconciliation = NeedleReconciliationEngine.reconcile(
      rawTranscript: transcript,
      geminiTaskJson: result,
      contextHeader: contextHeader,
    );

    final bool clarificationNeeded = reconciliation.status == 'clarification_needed';
    if (clarificationNeeded) {
      final String msg = (reconciliation.disambiguationPrompt ??
              result['clarification_message'] ??
              'Could you clarify what you want to do?')
          .toString();
      _currentDraft = {
        ...?_currentDraft,
        ...reconciliation.task,
      };
      _conversationHistory.add({'role': 'assistant', 'content': msg});
      _clarificationPrompt = msg;

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAiSpeaking = true;
        });

        // 1. Spoken clarification question aloud ("audio talk back")
        final timeoutMs = 7000 + (msg.length * 80);
        try {
          await _ttsService
              .speak(msg)
              .timeout(Duration(milliseconds: timeoutMs), onTimeout: () {
            debugPrint('CommandBar TTS playback timed out (${timeoutMs}ms). Recovering...');
          });
        } catch (e) {
          debugPrint('CommandBar TTS playback error: $e');
        }

        // Mandatory hardware settling delay before mic capture to prevent audio focus collision
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() {
            _isAiSpeaking = false;
          });
          // 2. Automatically resume recording for user's voice answer
          await _startVoiceCapture();
        }
      }
      return;
    }

    // Task extraction succeeded - reset conversational session
    _currentDraft = null;
    _conversationHistory.clear();
    _clarificationPrompt = null;

    // Multi-task handling
    if (reconciliation.tasks.length > 1) {
      final List<String> createdTitles = [];
      final List<String> createdIds = [];
      for (final t in reconciliation.tasks) {
        final tTitle = (t['title'] ?? 'Task').toString();
        final tDesc = t['description'];
        DateTime? tDue;
        if (t['due_date'] != null) {
          tDue = DateTime.tryParse(t['due_date'].toString());
        }
        final tPriority = UnifiedTask.parsePriority(t['priority']?.toString());
        final tSubtasks = (t['subtasks'] as List? ?? []).map((st) {
          return {
            'id': const Uuid().v4(),
            'title': st is Map ? (st['title'] ?? '').toString() : st.toString(),
            'is_completed': false,
          };
        }).toList();

        final bool tIsRecurring = t['is_recurring'] == true;
        RecurrenceRule? tRule;
        if (tIsRecurring && t['recurrence_rule'] is Map) {
          tRule = RecurrenceRule.fromMap(t['recurrence_rule']);
        }

        final cid = await taskProvider.addTask(
          title: tTitle,
          description: tDesc,
          communityId: t['community_id'],
          assignees: t['assignee'] != null && t['assignee'].toString().isNotEmpty && t['assignee'] != 'me'
              ? [t['assignee'].toString()]
              : [],
          subtasks: tSubtasks,
          priority: tPriority,
          status: Status.toDo,
          dueAt: tDue,
          isRecurring: tIsRecurring,
          recurrenceRule: tRule,
        );
        createdIds.add(cid);
        createdTitles.add(tTitle);
      }

      final confirmMsg = 'Created ${createdTitles.length} tasks: ${createdTitles.join(', ')}';
      unawaited(_ttsService.speak(confirmMsg));

      if (mounted) {
        _textController.clear();
        AppSnackBar.showUndo(
          context: context,
          message: 'Created ${createdTitles.length} tasks!',
          onUndo: () async {
            for (final id in createdIds) {
              await taskProvider.deleteTask(id);
            }
          },
          duration: const Duration(seconds: 5),
        );
      }
      return;
    }

    final verifiedTask = reconciliation.task;
    final title = (verifiedTask['title'] ?? result['title'] ?? 'New AI Task').toString();
    final description = verifiedTask['description'] ?? result['description'];

    DateTime? dueDate;
    if (verifiedTask['due_date'] != null) {
      dueDate = DateTime.tryParse(verifiedTask['due_date'].toString());
    }
    dueDate ??= AiService.parseAiDueDate(
      result['due_date'],
      result['due_time'] ?? result['time'],
    );

    final communityId = verifiedTask['community_id'] ?? result['community_id'];
    final assigneeId = verifiedTask['assignee'] ?? result['assignee_id'];
    final Priority priority = UnifiedTask.parsePriority(
      (verifiedTask['priority'] ?? result['priority'])?.toString(),
    );

    final bool isRecurring = verifiedTask['is_recurring'] == true;
    RecurrenceRule? recurrenceRule;
    if (isRecurring && verifiedTask['recurrence_rule'] is Map) {
      recurrenceRule = RecurrenceRule.fromMap(verifiedTask['recurrence_rule']);
    }

    final rawSubtasks = (verifiedTask['subtasks'] ?? result['subtasks']) as List? ?? [];
    final List<Map<String, dynamic>> subtaskMaps = [];
    for (int i = 0; i < rawSubtasks.length; i++) {
      final item = rawSubtasks[i];
      final subtaskTitle = item is Map ? (item['title'] ?? '').toString() : item.toString();
      if (subtaskTitle.trim().isNotEmpty) {
        subtaskMaps.add({
          'id': const Uuid().v4(),
          'title': subtaskTitle.trim(),
          'is_completed': item is Map ? (item['completed'] == true) : false,
          'order': i,
          if (item is Map && item['due_date'] != null) 'due_date': item['due_date'],
        });
      }
    }

    final createdId = await taskProvider.addTask(
      title: title,
      description: description,
      communityId: communityId,
      assignees: assigneeId != null && assigneeId.toString().isNotEmpty && assigneeId != 'me'
          ? [assigneeId.toString()]
          : [],
      subtasks: subtaskMaps,
      priority: priority,
      status: Status.toDo,
      dueAt: dueDate,
      isRecurring: isRecurring,
      recurrenceRule: recurrenceRule,
    );

    // Audio confirmation feedback
    final timeStr = dueDate != null
        ? '${dueDate.hour > 12 ? dueDate.hour - 12 : (dueDate.hour == 0 ? 12 : dueDate.hour)}:${dueDate.minute.toString().padLeft(2, '0')} ${dueDate.hour >= 12 ? 'PM' : 'AM'}'
        : 'soon';
    unawaited(_ttsService.speak('Created task: $title for $timeStr'));

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

        return ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer.withValues(alpha: 0.82),
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
                          : AppTheme.surfaceVariant),
                  width: (_isListening || _isLoading) ? 2 : 1,
                ),
              ),
              child: _isAiSpeaking
                  ? _buildAiSpeakingPill(colorScheme)
                  : (_isLoading
                      ? _buildLoadingPill(colorScheme)
                      : (_isListening
                          ? _buildListeningPill(colorScheme)
                          : _buildNormalInput(colorScheme))),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiSpeakingPill(ColorScheme colorScheme) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const Icon(
            Icons.volume_up_rounded,
            color: Color(0xFF88C0A4),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _clarificationPrompt ?? 'AI is asking a question...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF88C0A4),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white54),
            tooltip: 'Cancel',
            onPressed: _cancelConversation,
          ),
        ],
      ),
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
          Flexible(
            child: Text(
              _currentDraft != null
                  ? 'Processing answer...'
                  : 'AI is decomposing task & subtasks...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningPill(ColorScheme colorScheme) {
    return SizedBox(
      height: 40,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
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
            const SizedBox(width: 6),
            Text(
              _currentDraft != null ? 'Listening...' : 'Listening',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF88C0A4),
              ),
            ),
            const SizedBox(width: 6),
            AudioWaveformVisualizer(
              amplitudeStream: _audioService.amplitudeStream,
              barCount: 5,
              height: 18,
              barWidth: 2,
              barSpacing: 2,
              activeColor: const Color(0xFF88C0A4),
            ),
            const SizedBox(width: 12),
            StreamBuilder<Duration>(
              stream: _audioService.durationStream,
              initialData: _audioService.elapsed,
              builder: (context, snapshot) {
                final sec = (snapshot.data?.inSeconds ?? 0).clamp(0, 30);
                final display = '0:${sec.toString().padLeft(2, '0')}';
                return Text(
                  display,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.white70,
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _stopAndProcessVoice,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.close, size: 16, color: Colors.white54),
              tooltip: 'Cancel',
              onPressed: _cancelConversation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNormalInput(ColorScheme colorScheme) {
    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _textController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: _clarificationPrompt != null
                  ? 'AI: $_clarificationPrompt'
                  : 'Type a command or tap mic...',
              hintStyle: _clarificationPrompt != null
                  ? const TextStyle(
                      color: Color(0xFF88C0A4),
                      fontStyle: FontStyle.italic,
                    )
                  : null,
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (_) {
              _inputDebouncer.run(() {
                if (mounted) setState(() {});
              });
            },
            onSubmitted: (_) => _handleCommand(),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.mic_rounded,
            color: Color(0xFF88C0A4),
          ),
          onPressed: _isLoading ? null : () => _openVoiceOverlay(context),
          tooltip: 'AI Voice Assistant',
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
