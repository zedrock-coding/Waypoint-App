import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'models/unified_task.dart';
import 'providers/task_provider.dart';
import 'services/ai_service.dart';
import 'services/audio_recording_service.dart';
import 'services/supabase_service.dart';
import 'widgets/audio_waveform_visualizer.dart';
import 'features/voice/domain/controllers/audio_capture_controller.dart';
import 'features/voice/domain/models/recording_state.dart';

enum AIState { listening, processing, clarifying, preview, success, error }

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
  final AudioCaptureController _captureController = AudioCaptureController();
  AIState _currentState = AIState.listening;
  String _errorMessage = '';
  String _processingStageText = 'Analyzing audio with Gemini...';
  Timer? _processingStepTimer;

  Map<String, dynamic>? _currentDraft;
  String? _clarificationQuestion;
  final List<Map<String, String>> _conversationHistory = [];

  // Preview state fields
  String _previewTitle = '';
  String? _previewDescription;
  DateTime? _previewDueDate;
  Priority _previewPriority = Priority.medium;
  String? _previewCommunityId;
  String? _previewAssigneeId;
  final List<String> _previewSubtasks = [];
  final TextEditingController _newSubtaskController = TextEditingController();
  final TextEditingController _titleEditController = TextEditingController();
  bool _isAddingManualSubtask = false;
  bool _isEditingTitle = false;
  Timer? _autoConfirmTimer;
  int? _autoConfirmSeconds;

  void _startAutoConfirm() {
    _cancelAutoConfirm();
    _autoConfirmSeconds = 5;
    _autoConfirmTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _currentState != AIState.preview) {
        t.cancel();
        return;
      }
      setState(() {
        if (_autoConfirmSeconds != null && _autoConfirmSeconds! > 1) {
          _autoConfirmSeconds = _autoConfirmSeconds! - 1;
        } else {
          t.cancel();
          _autoConfirmSeconds = null;
          _commitPreviewTask();
        }
      });
    });
  }

  void _cancelAutoConfirm() {
    _autoConfirmTimer?.cancel();
    _autoConfirmTimer = null;
    if (_autoConfirmSeconds != null && mounted) {
      setState(() => _autoConfirmSeconds = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _audioService.onTimeout = () {
      if (mounted &&
          (_currentState == AIState.listening ||
              _currentState == AIState.clarifying)) {
        _finishRecordingAndProcess();
      }
    };

    _startListening();
  }

  Future<void> _startListening() async {
    _captureController.startRecording(
      onLimitReached: () {
        if (mounted &&
            (_currentState == AIState.listening ||
                _currentState == AIState.clarifying)) {
          _finishRecordingAndProcess();
        }
      },
    );

    final ok = await _audioService.startRecording();
    if (!ok && mounted) {
      _captureController.stop();
      setState(() {
        _currentState = AIState.error;
        _errorMessage = 'Microphone permission denied or not available';
      });
    }
  }

  Future<void> _finishRecordingAndProcess() async {
    if (_currentState != AIState.listening &&
        _currentState != AIState.clarifying) {
      return;
    }

    _captureController.stop();

    setState(() {
      _currentState = AIState.processing;
      _processingStageText = 'Transcribing audio with Gemini...';
    });

    _processingStepTimer?.cancel();
    _processingStepTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && _currentState == AIState.processing) {
        setState(() {
          _processingStageText = 'Decomposing task & subtask milestones...';
        });
      }
    });

    final Uint8List? audioBytes = await _audioService.stopRecording();
    if (audioBytes == null || audioBytes.length < 500) {
      _processingStepTimer?.cancel();
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

      _processingStepTimer?.cancel();

      if (result != null) {
        final bool needsClarification = result['clarification_needed'] == true;

        if (needsClarification) {
          final question = result['clarification_message'] ??
              'Could you clarify when this task is due or needed?';
          _conversationHistory.add({'role': 'assistant', 'content': question});

          if (mounted) {
            setState(() {
              _currentDraft = result;
              _clarificationQuestion = question;
              _currentState = AIState.clarifying;
            });
            await _startListening();
          }
          return;
        }

        // Gather extracted task and decompose subtasks into interactive preview
        final title =
            result['title'] ?? (_currentDraft?['title'] ?? 'Voice Task');
        final description =
            result['description'] ?? _currentDraft?['description'];

        final dueDate = AiService.parseAiDueDate(
          result['due_date'] ?? _currentDraft?['due_date'],
          result['due_time'] ??
              result['time'] ??
              _currentDraft?['due_time'] ??
              _currentDraft?['time'],
        );

        final communityId =
            result['community_id'] ?? _currentDraft?['community_id'];
        final assigneeId =
            result['assignee_id'] ?? _currentDraft?['assignee_id'];
        final Priority priority = UnifiedTask.parsePriority(
          (result['priority'] ?? _currentDraft?['priority'])?.toString(),
        );

        final rawSubtasks =
            (result['subtasks'] ?? _currentDraft?['subtasks']) as List? ?? [];
        final List<String> extractedSubtasks = rawSubtasks
            .map((e) => e.toString().trim())
            .where((st) => st.isNotEmpty)
            .toList();

        if (mounted) {
          setState(() {
            _previewTitle = title;
            _previewDescription = description;
            _previewDueDate = dueDate;
            _previewPriority = priority;
            _previewCommunityId = communityId;
            _previewAssigneeId = assigneeId;
            _previewSubtasks.clear();
            _previewSubtasks.addAll(extractedSubtasks);
            _isEditingTitle = false;
            _isAddingManualSubtask = false;
            _currentState = AIState.preview;
          });
          _startAutoConfirm();
        }
      } else {
        throw Exception('Failed to interpret voice command');
      }
    } catch (e) {
      _processingStepTimer?.cancel();
      debugPrint('AIVoiceOverlay error: $e');
      if (mounted) {
        setState(() {
          _currentState = AIState.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _commitPreviewTask() async {
    _cancelAutoConfirm();
    final taskProvider = context.read<TaskProvider>();
    final effectiveTitle =
        _previewTitle.trim().isNotEmpty ? _previewTitle.trim() : 'Voice Task';

    final List<Map<String, dynamic>> subtaskMaps = _previewSubtasks
        .asMap()
        .entries
        .map((e) => {
              'id': const Uuid().v4(),
              'title': e.value.trim(),
              'is_completed': false,
              'order': e.key,
            })
        .where((st) => (st['title'] as String).isNotEmpty)
        .toList();

    try {
      await taskProvider.addTask(
        title: effectiveTitle,
        description: _previewDescription,
        communityId: _previewCommunityId,
        assignees:
            _previewAssigneeId != null ? [_previewAssigneeId!] : [],
        subtasks: subtaskMaps,
        priority: _previewPriority,
        status: Status.toDo,
        dueAt: _previewDueDate,
      );

      if (mounted) {
        setState(() => _currentState = AIState.success);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentState = AIState.error;
          _errorMessage = 'Failed to create task: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _cancelAutoConfirm();
    _processingStepTimer?.cancel();
    _pulseController.dispose();
    _captureController.dispose();
    _audioService.dispose();
    _newSubtaskController.dispose();
    _titleEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1E2124),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top grab handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (_currentState == AIState.preview)
              _buildPreviewState(colorScheme)
            else ...[
              _buildCenterGraphic(colorScheme),
              const SizedBox(height: 20),
              _buildStatusText(colorScheme),
              const SizedBox(height: 12),
              _buildSubtext(colorScheme),
              if (_currentState == AIState.error) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _currentState = AIState.listening);
                        _startListening();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF88C0A4),
                        foregroundColor: const Color(0xFF1E2124),
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewState(ColorScheme colorScheme) {
    final priorityColor = switch (_previewPriority) {
      Priority.high => const Color(0xFFFF5252),
      Priority.medium => const Color(0xFFFFBF00),
      Priority.low => const Color(0xFF78909C),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF88C0A4),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Review Task & Milestones',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Extracted task title & chips
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2F31),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF88C0A4).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditingTitle)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleEditController,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Task title...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF24272B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF88C0A4)),
                          ),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            setState(() {
                              _previewTitle = val.trim();
                              _isEditingTitle = false;
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.check,
                        color: Color(0xFF88C0A4),
                        size: 18,
                      ),
                      onPressed: () {
                        final val = _titleEditController.text.trim();
                        if (val.isNotEmpty) {
                          setState(() {
                            _previewTitle = val;
                            _isEditingTitle = false;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _isEditingTitle = false),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _previewTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFF88C0A4),
                      ),
                      tooltip: 'Edit title',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onPressed: () {
                        _cancelAutoConfirm();
                        _titleEditController.text = _previewTitle;
                        setState(() => _isEditingTitle = true);
                      },
                    ),
                  ],
                ),
              if (_previewDescription != null &&
                  _previewDescription!.isNotEmpty &&
                  _previewDescription != _previewTitle) ...[
                const SizedBox(height: 6),
                Text(
                  _previewDescription!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: priorityColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _previewPriority.name.toUpperCase(),
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_previewDueDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, h:mm a').format(_previewDueDate!),
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Subtask Milestones Section
        Row(
          children: [
            const Icon(
              Icons.checklist_rounded,
              size: 16,
              color: Color(0xFF88C0A4),
            ),
            const SizedBox(width: 6),
            Text(
              'Subtask Milestones (${_previewSubtasks.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (!_isAddingManualSubtask)
              TextButton.icon(
                onPressed: () {
                  _cancelAutoConfirm();
                  setState(() => _isAddingManualSubtask = true);
                },
                icon: const Icon(
                  Icons.add,
                  size: 14,
                  color: Color(0xFF88C0A4),
                ),
                label: const Text(
                  'Add Milestone',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF88C0A4),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_previewSubtasks.isEmpty && !_isAddingManualSubtask)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No subtasks generated for this task.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _previewSubtasks.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF24272B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF88C0A4).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF88C0A4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _previewSubtasks[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 16,
                        onPressed: () {
                          _cancelAutoConfirm();
                          setState(() {
                            _previewSubtasks.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (_isAddingManualSubtask) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSubtaskController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'New milestone title...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF24272B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF88C0A4)),
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      setState(() {
                        _previewSubtasks.add(val.trim());
                        _newSubtaskController.clear();
                        _isAddingManualSubtask = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check, color: Color(0xFF88C0A4)),
                onPressed: () {
                  final text = _newSubtaskController.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      _previewSubtasks.add(text);
                      _newSubtaskController.clear();
                      _isAddingManualSubtask = false;
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () {
                  setState(() {
                    _newSubtaskController.clear();
                    _isAddingManualSubtask = false;
                  });
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _cancelAutoConfirm();
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Discard'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _commitPreviewTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF88C0A4),
                  foregroundColor: const Color(0xFF1E2124),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: Text(
                  _autoConfirmSeconds != null
                      ? 'Add to Workspace (${_autoConfirmSeconds}s)'
                      : 'Add to Workspace',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubtext(ColorScheme colorScheme) {
    if (_currentState == AIState.listening) {
      return Column(
        children: [
          StreamBuilder<RecordingState>(
            stream: _captureController.stream,
            initialData: _captureController.state,
            builder: (context, snapshot) {
              final remaining =
                  snapshot.data?.remaining ?? const Duration(seconds: 30);
              final seconds = remaining.inSeconds.clamp(0, 30);
              return Text(
                '00:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Speak your task and subtasks, then tap Done',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _finishRecordingAndProcess,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF88C0A4),
              foregroundColor: const Color(0xFF1E2124),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text(
              'Done Speaking \u2192 Process',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
                color: const Color(0xFF88C0A4).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF88C0A4).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Task: "${_currentDraft!['title']}"',
                style: const TextStyle(
                  color: Color(0xFF88C0A4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const Text(
            'Speak your answer, then tap to process',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _finishRecordingAndProcess,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Process Answer'),
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
        final accentColor = _currentState == AIState.clarifying
            ? Colors.amberAccent
            : const Color(0xFF88C0A4);

        return Column(
          children: [
            AudioWaveformVisualizer(
              amplitudeStream: _audioService.amplitudeStream,
              barCount: 11,
              height: 54,
              barWidth: 4.5,
              barSpacing: 4.5,
              activeColor: accentColor,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _finishRecordingAndProcess,
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.mic,
                        size: 40,
                        color: accentColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      case AIState.processing:
        return const SizedBox(
          height: 80,
          width: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF88C0A4)),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                size: 28,
                color: Color(0xFF88C0A4),
              ),
            ],
          ),
        );
      case AIState.success:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF88C0A4),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            size: 44,
            color: Color(0xFF1E2124),
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
            size: 44,
            color: Colors.redAccent,
          ),
        );
      case AIState.preview:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusText(ColorScheme colorScheme) {
    switch (_currentState) {
      case AIState.listening:
        return const Text(
          'Waypoint is listening...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
      case AIState.clarifying:
        return Text(
          _clarificationQuestion ?? 'Could you clarify the details?',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.amberAccent,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        );
      case AIState.processing:
        return Text(
          _processingStageText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      case AIState.success:
        return const Text(
          'Task Added Successfully',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
      case AIState.error:
        return Text(
          _errorMessage.isNotEmpty ? _errorMessage : 'Something went wrong',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        );
      case AIState.preview:
        return const SizedBox.shrink();
    }
  }
}
