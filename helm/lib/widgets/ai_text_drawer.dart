import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';
import '../providers/task_provider.dart';
import '../models/unified_task.dart';

class AITextDrawer extends StatefulWidget {
  const AITextDrawer({super.key});

  @override
  State<AITextDrawer> createState() => _AITextDrawerState();
}

class _AITextDrawerState extends State<AITextDrawer> {
  final _textController = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(text: "Hello! How can I help you manage your tasks today?", isUser: false),
  ];
  bool _isLoading = false;

  Future<void> _handleSend() async {
    final input = _textController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: input, isUser: true));
      _textController.clear();
      _isLoading = true;
    });

    final aiService = context.read<AiService>();
    final taskProvider = context.read<TaskProvider>();
    final supabaseService = SupabaseService();

    try {
      final communities = await supabaseService.fetchUserCommunities();
      final members = await supabaseService.fetchAllAccessibleMembers();

      final result = await aiService.parseTaskCommand(
        userInput: input,
        availableCommunities: communities,
        availableMembers: members,
      );

      if (result != null) {
        final title = result['title'] ?? 'New AI Task';
        final dueDate = result['due_date'] != null ? DateTime.parse(result['due_date']) : null;
        final priorityStr = (result['priority'] ?? 'MEDIUM').toString().toLowerCase();
        final communityId = result['community_id'];
        final assigneeId = result['assignee_id'];

        Priority priority = Priority.medium;
        if (priorityStr == 'high') priority = Priority.high;
        if (priorityStr == 'low') priority = Priority.low;

        await taskProvider.addTask(
          title: title,
          description: "Created via AI Assistant: $input",
          communityId: communityId,
          assignees: assigneeId != null ? [assigneeId] : [],
          priority: priority,
          status: Status.toDo,
          dueAt: dueDate,
        );

        setState(() {
          String responseText = "Done! I've created the task '$title'";
          if (communityId != null) {
            final comm = communities.firstWhere((c) => c['id'] == communityId, orElse: () => {});
            if (comm.isNotEmpty) responseText += " in ${comm['name']}";
          }
          _messages.add(_ChatMessage(text: "$responseText.", isUser: false));
        });
      } else {
        setState(() {
          _messages.add(_ChatMessage(text: "I couldn't parse that command. Could you try rephrasing?", isUser: false));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(text: "Sorry, I ran into an error: $e", isUser: false));
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 800;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: isDesktop ? 400 : width * 0.85,
      child: Drawer(
        backgroundColor: colorScheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'AI Assistant',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _ChatBubble(text: msg.text, isUser: msg.isUser);
                },
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(),
              ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(top: BorderSide(color: colorScheme.outlineVariant, width: 0.5)),
              ),
              child: TextField(
                controller: _textController,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: 'Type a task command...',
                  hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 14),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send, color: colorScheme.primary),
                    onPressed: _isLoading ? null : _handleSend,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primaryContainer.withOpacity(0.5) : colorScheme.surface,
          border: isUser ? null : Border.all(color: colorScheme.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
