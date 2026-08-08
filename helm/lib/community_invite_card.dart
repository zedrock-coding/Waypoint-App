import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommunityInviteCard extends StatelessWidget {
  final String communityName;
  final String inviteId;

  const CommunityInviteCard({
    super.key,
    required this.communityName,
    required this.inviteId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String inviteLink = "app.helm/invite/$inviteId";

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Invite to $communityName",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      inviteLink,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 20, color: colorScheme.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Invite Link Copied!"),
                          behavior: SnackBarBehavior.floating,
                          width: 300,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: colorScheme.inverseSurface,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
