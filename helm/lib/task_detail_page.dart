import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/unified_task.dart';
import 'models/hive_models.dart' as hive_model;
import 'widgets/task_form_utils.dart';
import 'providers/task_provider.dart';
import 'services/supabase_service.dart';

class TaskDetailScreen extends StatelessWidget {
  final UnifiedTask task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: TaskDetailContent(task: task),
    );
  }
}

class TaskDetailContent extends StatefulWidget {
  final UnifiedTask task;
  final VoidCallback? onClose;
  final bool useHero;

  const TaskDetailContent({
    super.key, 
    required this.task, 
    this.onClose,
    this.useHero = true,
  });

  @override
  State<TaskDetailContent> createState() => _TaskDetailContentState();
}

class _TaskDetailContentState extends State<TaskDetailContent> {
  bool _isReadOnly = false;
  bool _loadingPerms = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (widget.task.communityId == null) {
      if (mounted) setState(() => _loadingPerms = false);
      return;
    }

    try {
      final members = await SupabaseService().getCommunityMembers(widget.task.communityId!);
      final myId = Supabase.instance.client.auth.currentUser?.id;
      final creatorId = widget.task.userId;

      final me = members.firstWhere((m) => m['user_id'] == myId, orElse: () => {});
      final creator = members.firstWhere((m) => m['user_id'] == creatorId, orElse: () => {});

      int getWeight(String? r) {
        if (r == 'owner') return 3;
        if (r == 'admin') return 2;
        return 1;
      }

      final myWeight = getWeight(me['role']);
      final creatorWeight = getWeight(creator['role']);

      if (mounted) {
        setState(() {
          _isReadOnly = myWeight < creatorWeight;
          _loadingPerms = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPerms = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 100) return const SizedBox.shrink();

        Widget content = Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (!_loadingPerms && _isReadOnly)
                    Container(
                      color: Colors.orange.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 14, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Read-Only: Task created by Admin/Owner',
                            style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  // 1. Header Section (Title & Tags)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.onClose != null) const SizedBox(height: 32),
                        Text(
                          widget.task.title,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTags(context),
                      ],
                    ),
                  ),
                  
                  // 2. Body Section (Details & Subtasks)
                  AbsorbPointer(
                    absorbing: _isReadOnly,
                    child: Opacity(
                      opacity: _isReadOnly ? 0.7 : 1.0,
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.2),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(context, 'Description'),
                              const SizedBox(height: 8),
                              Text(
                                widget.task.description.isNotEmpty ? widget.task.description : 'No description provided.',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              _buildInfoRow(
                                context, 
                                icon: Icons.access_time, 
                                label: 'Date', 
                                value: DateFormat.yMMMMd().add_jm().format(widget.task.dateTime),
                              ),
                              
                              const SizedBox(height: 40),
                              _buildSectionTitle(context, 'Sub-tasks'),
                              const SizedBox(height: 16),
                              if (widget.task.subtasks.isEmpty)
                                const Center(child: Text('No sub-tasks.'))
                              else
                                ...List.generate(widget.task.subtasks.length, (index) {
                                  final sub = widget.task.subtasks[index];
                                  final bool isCompleted = sub['is_completed'] ?? false;
                                  return CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      sub['title'] ?? '',
                                      style: TextStyle(
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                        color: isCompleted ? colorScheme.onSurface.withOpacity(0.5) : colorScheme.onSurface,
                                      ),
                                    ),
                                    value: isCompleted,
                                    onChanged: _isReadOnly ? null : (_) {
                                      context.read<TaskProvider>().toggleSubtask(widget.task.id, index);
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    dense: true,
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Comments are now outside the AbsorbPointer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(context, 'Comments'),
                        const SizedBox(height: 16),
                        _TaskCommentsSection(task: widget.task),
                      ],
                    ),
                  ),
                ],
              ),

              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isReadOnly)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          showAddTaskForm(context, taskToEdit: widget.task);
                        },
                        tooltip: 'Edit Task',
                      ),
                    if (widget.onClose != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: widget.onClose,
                        tooltip: 'Close Panel',
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (widget.useHero) {
          return Hero(
            tag: 'task_card_${widget.task.id}',
            child: content,
          );
        }
        return content;
      },
    );
  }

  Widget _buildTags(BuildContext context) {
    final box = Hive.box<hive_model.Category>('categories');
    final categoryNames = widget.task.categoryIds
        .map((id) => box.get(id)?.name)
        .whereType<String>()
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPill(context, widget.task.priority.name.toUpperCase(), isPriority: true),
        for (var name in categoryNames) _buildPill(context, name.toUpperCase()),
        if (!widget.task.isLocal) _buildPill(context, 'CLOUD'),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label, 
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.5)),
                ),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(BuildContext context, String label, {bool isPriority = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPriority ? colorScheme.primary : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPriority ? colorScheme.onPrimary : colorScheme.onSecondaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TaskCommentsSection extends StatefulWidget {
  final UnifiedTask task;
  const _TaskCommentsSection({required this.task});

  @override
  State<_TaskCommentsSection> createState() => _TaskCommentsSectionState();
}

class _TaskCommentsSectionState extends State<_TaskCommentsSection> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await context.read<TaskProvider>().addComment(widget.task.id, text);
      if (mounted) _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.read<TaskProvider>();
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: taskProvider.streamTaskComments(widget.task.id),
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> rawComments = snapshot.data ?? [];
        
        // Deduplicate comments by ID to prevent "double send" visual bugs
        final Map<String, Map<String, dynamic>> uniqueComments = {};
        for (var c in rawComments) {
          if (c['id'] != null) {
            uniqueComments[c['id'].toString()] = c;
          }
        }
        final comments = uniqueComments.values.toList();
        
        // Calculate 2-comment limit logic
        final myRecentComments = comments.where((c) {
          final createdAt = DateTime.parse(c['created_at']);
          return c['user_id'] == userId && createdAt.isAfter(widget.task.updatedAt.subtract(const Duration(seconds: 1)));
        }).toList();

        final bool limitReached = myRecentComments.length >= 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comments.isEmpty)
              const Center(child: Text('No comments yet.'))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final c = comments[index];
                  final isMe = c['user_id'] == userId;
                  return _CommentBubble(
                    userName: c['user_name'] ?? 'User',
                    text: c['comment_text'] ?? '',
                    isMe: isMe,
                    time: DateTime.parse(c['created_at']),
                  );
                },
              ),
            const SizedBox(height: 24),
            if (limitReached)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Comment limit reached (2/2). Updating the task status or details will unlock 2 fresh comment slots.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  suffixIcon: IconButton(
                    onPressed: _isSubmitting ? null : _submitComment,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ),
                onSubmitted: (_) => _submitComment(),
              ),
          ],
        );
      },
    );
  }
}

class _CommentBubble extends StatelessWidget {
  final String userName;
  final String text;
  final bool isMe;
  final DateTime time;

  const _CommentBubble({required this.userName, required this.text, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            '$userName • ${DateFormat.jm().format(time)}',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.4)),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
