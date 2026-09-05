import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_service.dart';
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
    super.dispose();
  }

  Future<void> _toggleListening() async {
    try {
      if (!_isListening) {
        bool available = await _stt.initialize(
          onStatus: (status) {
            debugPrint('STT Status: $status');
            if (status == 'notListening' && mounted) {
              setState(() => _isListening = false);
            }
          },
          onError: (error) {
            debugPrint('STT Error: $error');
            if (mounted) {
              setState(() => _isListening = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Voice Error: ${error.errorMsg}')),
              );
            }
          },
        );

        if (available) {
          setState(() => _isListening = true);
          _stt.listen(
            onResult: (result) {
              if (mounted) {
                setState(() {
                  _textController.text = result.recognizedWords;
                });
              }
            },
          );
        } else {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Speech recognition not available on this device.')),
            );
          }
        }
      } else {
        setState(() => _isListening = false);
        _stt.stop();
      }
    } catch (e) {
      debugPrint('STT Initialization Error: $e');
    }
  }

  Future<void> _handleCommand() async {
    final input = _textController.text.trim();
    if (input.isEmpty) return;

    // Stop listening if we are
    if (_isListening) {
      _stt.stop();
      setState(() => _isListening = false);
    }

    setState(() => _isLoading = true);
    final aiService = context.read<AiService>();
    final taskProvider = context.read<TaskProvider>();
    final supabaseService = SupabaseService();

    try {
      // 1. Fetch Context
      final communities = await supabaseService.fetchUserCommunities();
      final members = await supabaseService.fetchAllAccessibleMembers();

      // 2. AI Parse
      final result = await aiService.parseTaskCommand(
        userInput: input,
        availableCommunities: communities,
        availableMembers: members,
      );

      if (result != null) {
        final title = result['title'] ?? 'New AI Task';
        final description = result['description']; // Inject AI generated description
        final dueDate = result['due_date'] != null ? DateTime.tryParse(result['due_date']) : null;
        final priorityStr = (result['priority'] ?? 'MEDIUM').toString().toLowerCase();
        final communityId = result['community_id'];
        final assigneeId = result['assignee_id'];

        Priority priority = Priority.medium;
        if (priorityStr == 'high') priority = Priority.high;
        if (priorityStr == 'low') priority = Priority.low;

        // 3. Create Task
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
      } else {
        throw Exception("Failed to understand the command.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Error: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
