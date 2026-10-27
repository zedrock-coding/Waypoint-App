import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_service.dart';
import '../services/audio_recording_service.dart';
import '../services/supabase_service.dart';
import '../providers/task_provider.dart';
import '../models/unified_task.dart';

class CommandBarWidget extends StatefulWidget {
  const CommandBarWidget({super.key});

  @override
  State<CommandBarWidget> createState() => _CommandBarWidgetState();
}

class _CommandBarWidgetState extends State<CommandBarWidget> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _stt = stt.SpeechToText();
  final _audioService = AudioRecordingService();
  bool _isListening = false;
  bool _isLoading = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
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
      if (!_isListening) {
        // 1. Start Audio Recording stream for Direct Multimodal ingestion
        final startedAudio = await _audioService.startRecording();
        
        // 2. Start STT for live visual preview in text field
        bool sttAvailable = false;
        try {
          sttAvailable = await _stt.initialize(
            onStatus: (status) {
              if (status == 'notListening' && mounted && _isListening) {
                // If STT stops on silence, trigger command completion
                _stopAndProcessVoice();
              }
            },
            onError: (error) {
              debugPrint('STT Preview Error: $error');
            },
          );
          if (sttAvailable) {
            _stt.listen(
              onResult: (result) {
                if (mounted) {
                  setState(() {
                    _textController.text = result.recognizedWords;
                  });
                }
              },
            );
          }
        } catch (e) {
          debugPrint('STT fallback init failed: $e');
        }

        if (startedAudio || sttAvailable) {
          setState(() => _isListening = true);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audio recording is not available.')),
            );
          }
        }
      } else {
        await _stopAndProcessVoice();
      }
    } catch (e) {
      debugPrint('Voice toggle error: $e');
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopAndProcessVoice() async {
    if (!_isListening) return;

    setState(() => _isListening = false);
    _stt.stop();
    final audioBytes = await _audioService.stopRecording();

    if (audioBytes != null && audioBytes.length > 500) {
      // Direct Multimodal audio pipeline
      await _handleVoiceCommand(audioBytes);
    } else {
      // Fallback to text in controller
      await _handleCommand();
    }
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
            content: Text('AI Voice Error: ${e.toString().replaceAll('Exception: ', '')}'),
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

      // Hybrid parse: Needle 3 on edge for fast paths, Gemini cloud for de-jumbling
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
            content: Text('AI Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyTaskResult(Map<String, dynamic>? result, TaskProvider taskProvider) async {
    if (result == null) {
      throw Exception('Could not understand task command.');
    }

    final bool clarificationNeeded = result['clarification_needed'] ?? false;
    if (clarificationNeeded) {
      if (mounted) {
        final msg = result['clarification_message'] ?? 'Could you clarify what you want to do?';
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

    DateTime? dueDate;
    if (result['due_date'] != null && result['due_date'].toString().isNotEmpty) {
      final parsed = DateTime.tryParse(result['due_date'].toString());
      if (parsed != null) {
        dueDate = DateTime(parsed.year, parsed.month, parsed.day, 12, 0, 0);
      }
    }

    final priorityStr = (result['priority'] ?? 'MEDIUM').toString().toLowerCase();
    final communityId = result['community_id'];
    final assigneeId = result['assignee_id'];

    Priority priority = Priority.medium;
    if (priorityStr == 'high') priority = Priority.high;
    if (priorityStr == 'low') priority = Priority.low;

    await taskProvider.addTask(
      title: title,
      description: description,
      communityId: communityId,
      assignees: assigneeId != null ? [assigneeId] : [],
      priority: priority,
      status: Status.toDo,
      dueAt: dueDate,
    );

    if (mounted) {
      _textController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Task Created!'), behavior: SnackBarBehavior.floating),
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
                color: _isListening ? Colors.red.withOpacity(0.2) : colorScheme.primary.withOpacity(0.15 * glow),
                blurRadius: _isListening ? 15 : 10 * glow,
                spreadRadius: _isListening ? 2 : 2 * glow,
              )
            ],
            border: Border.all(
              color: _isListening ? Colors.red : (_isLoading ? colorScheme.primary : colorScheme.outlineVariant.withOpacity(0.5)),
              width: (_isListening || _isLoading) ? 2 : 1,
            ),
          ),
          child: Row(
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
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : colorScheme.primary,
                ),
                onPressed: _isLoading ? null : _toggleListening,
              ),
              IconButton(
                icon: Icon(Icons.send_rounded, color: _textController.text.isEmpty ? Colors.grey : colorScheme.primary),
                onPressed: (_isLoading || _textController.text.isEmpty) ? null : _handleCommand,
              ),
            ],
          ),
        );
      },
    );
  }
}
