import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/unified_task.dart';
import 'providers/task_provider.dart';
import 'services/ai_service.dart';
import 'services/audio_recording_service.dart';
import 'services/supabase_service.dart';

enum AIState { listening, processing, success, error }

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
    if (_currentState != AIState.listening) return;

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
      final communities = await supabaseService.fetchUserCommunities();
      final members = await supabaseService.fetchAllAccessibleMembers();

      final result = await aiService.parseVoiceCommand(
        audioBytes: audioBytes,
        availableCommunities: communities,
        availableMembers: members,
      );

      if (result != null) {
        final title = result['title'] ?? 'Voice Task';
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
          const SizedBox(height: 24),
          _buildStatusText(colorScheme),
          const SizedBox(height: 8),
          if (_currentState == AIState.listening)
            const Text(
              "Tap microphone when done speaking",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
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

  Widget _buildCenterGraphic(ColorScheme colorScheme) {
    switch (_currentState) {
      case AIState.listening:
        return GestureDetector(
          onTap: _finishRecordingAndProcess,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic,
                    size: 48,
                    color: Colors.tealAccent,
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
            color: Colors.redAccent.withOpacity(0.2),
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
    String text;
    switch (_currentState) {
      case AIState.listening:
        text = "Helm is listening...";
        break;
      case AIState.processing:
        text = "De-jumbling & Creating Task...";
        break;
      case AIState.success:
        text = "Task Added Successfully";
        break;
      case AIState.error:
        text = _errorMessage.isNotEmpty ? _errorMessage : "Something went wrong";
        break;
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
