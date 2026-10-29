import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/unified_task.dart';
import 'providers/task_provider.dart';
import 'services/ai_service.dart';
import 'services/audio_recording_service.dart';
import 'services/supabase_service.dart';

enum AIState { listening, processing, clarifying, success, error }

class AIVoiceOverlay extends StatefulWidget {
  const AIVoiceOverlay({super.key});

  @override
  State<AIVoiceOverlay> createState() => _AIVoiceOverlayState();
}

class _AIVoiceOverlayState extends State<AIVoiceOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  final AudioRecordingService _audioService = AudioRecordingService();
  AIState _currentState = AIState.listening;
  String _errorMessage = '';

  Map<String, dynamic>? _currentDraft;
  String? _clarificationQuestion;
  final List<Map<String, String>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startListening();
  }

  Future<void> _startListening() async {
    final ok = await _audioService.startRecording();
    if (!ok && mounted) {
      setState(() {
        _currentState = AIState.error;
        _errorMessage = 'Microphone permission denied or not available';
      });
    }
  }

  Future<void> _finishRecordingAndProcess() async {
    if (_currentState != AIState.listening && _currentState != AIState.clarifying) return;

    setState(() => _currentState = AIState.processing);

    final Uint8List? audioBytes = await _audioService.stopRecording();
    if (audioBytes == null || audioBytes.length < 500) {
      if (mounted) {
        setState(() {
          _currentState = AIState.error;
          _errorMessage = 'No audio recorded. Please try again.';
        });
      }
      return;
    }

    if (!mounted) return;
    final aiService = context.read<AiService>();
    final taskProvider = context.read<TaskProvider>();
    final supabaseService = SupabaseService();

    try {
      List<Map<String, dynamic>> communities = [];
      List<Map<String, dynamic>> members = [];
      try {
        communities = await supabaseService.fetchUserCommunities();
        members = await supabaseService.fetchAllAccessibleMembers();
      } catch (e) {
        debugPrint('AIVoiceOverlay: Remote community fetch skipped: $e');
      }

      final result = await aiService.parseVoiceCommand(
        audioBytes: audioBytes,
        availableCommunities: communities,
        availableMembers: members,
        currentDraft: _currentDraft,
        conversationHistory: _conversationHistory,
      );

      if (result != null) {
        final bool needsClarification = result['clarification_needed'] == true;

        if (needsClarification) {
          // AI proactively asks for missing details in a conversation
          final question = result['clarification_message'] ?? 'Could you clarify when this task is due or needed?';
          _conversationHistory.add({'role': 'assistant', 'content': question});
          
          if (mounted) {
            setState(() {
              _currentDraft = result;
              _clarificationQuestion = question;
              _currentState = AIState.clarifying;
            });
            // Automatically arm microphone for the next answer turn
            await _startListening();
          }
          return;
        }

        // Complete details gathered - finalize task
        final title = result['title'] ?? (_currentDraft?['title'] ?? 'Voice Task');
        final description = result['description'] ?? _currentDraft?['description'];

        final dueDate = AiService.parseAiDueDate(
          result['due_date'] ?? _currentDraft?['due_date'],
          result['due_time'] ?? result['time'] ?? _currentDraft?['due_time'] ?? _currentDraft?['time'],
        );

        final communityId = result['community_id'] ?? _currentDraft?['community_id'];
        final assigneeId = result['assignee_id'] ?? _currentDraft?['assignee_id'];
        final Priority priority = UnifiedTask.parsePriority(
          (result['priority'] ?? _currentDraft?['priority'])?.toString(),
        );

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
          setState(() => _currentState = AIState.success);
          await Future.delayed(const Duration(milliseconds: 1200));
          if (mounted) Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to interpret voice command');
      }
    } catch (e) {
      debugPrint('AIVoiceOverlay error: $e');
      if (mounted) {
        setState(() {
          _currentState = AIState.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCenterGraphic(colorScheme),
          const SizedBox(height: 20),
          _buildStatusText(colorScheme),
          const SizedBox(height: 10),
          _buildSubtext(colorScheme),
          if (_currentState == AIState.error) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _currentState = AIState.listening);
                _startListening();
              },
              child: const Text('Try Again', style: TextStyle(color: Colors.tealAccent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtext(ColorScheme colorScheme) {
    if (_currentState == AIState.listening) {
      return const Text(
        "Speak your task, then tap mic when done",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white54, fontSize: 13),
      );
    }

    if (_currentState == AIState.clarifying) {
      return Column(
        children: [
          if (_currentDraft?['title'] != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Task: "${_currentDraft!['title']}"',
                style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          const Text(
            "Speak your answer, then tap mic to confirm",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCenterGraphic(ColorScheme colorScheme) {
    switch (_currentState) {
      case AIState.listening:
      case AIState.clarifying:
        return GestureDetector(
          onTap: _finishRecordingAndProcess,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              final color = _currentState == AIState.clarifying ? Colors.amberAccent : Colors.tealAccent;
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 48,
                    color: color,
                  ),
                ),
              );
            },
          ),
        );
      case AIState.processing:
        return const SizedBox(
          height: 80,
          width: 80,
          child: CircularProgressIndicator(
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          ),
        );
      case AIState.success:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: Colors.white,
          ),
        );
      case AIState.error:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Colors.redAccent,
          ),
        );
    }
  }

  Widget _buildStatusText(ColorScheme colorScheme) {
    switch (_currentState) {
      case AIState.listening:
        return const Text(
          "Helm is listening...",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        );
      case AIState.clarifying:
        return Text(
          _clarificationQuestion ?? "Could you clarify the details?",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.amberAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
      case AIState.processing:
        return const Text(
          "Refining & Finalizing...",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        );
      case AIState.success:
        return const Text(
          "Task Added Successfully",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        );
      case AIState.error:
        return Text(
          _errorMessage.isNotEmpty ? _errorMessage : "Something went wrong",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        );
    }
  }
}
