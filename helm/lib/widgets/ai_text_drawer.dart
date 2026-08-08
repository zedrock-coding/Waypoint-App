import 'package:flutter/material.dart';

class AITextDrawer extends StatelessWidget {
  const AITextDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isDesktop = width >= 800;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: isDesktop ? 350 : width * 0.8,
      child: Drawer(
        backgroundColor: colorScheme.surface,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'AI Assistant',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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

            // Chat Messages
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildUserBubble(context, "Add a team sync at 5 PM"),
                  const SizedBox(height: 16),
                  _buildAIBubble(context, "Team sync created for 5 PM and added to your Work community."),
                ],
              ),
            ),

            // Input Field
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(top: BorderSide(color: colorScheme.outlineVariant, width: 0.5)),
              ),
              child: TextField(
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
                    onPressed: () {
                      // Placeholder for send action
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildAIBubble(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.primary.withOpacity(0.5)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
