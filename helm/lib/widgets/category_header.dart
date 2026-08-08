import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CategoryHeaderRow extends StatelessWidget {
  final String categoryName;
  final VoidCallback onAddPressed;

  const CategoryHeaderRow({
    super.key,
    required this.categoryName,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              categoryName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.add, color: colorScheme.onPrimary, size: 20),
              onPressed: () {
                HapticFeedback.lightImpact();
                onAddPressed();
              },
            ),
          ),
        ],
      ),
    );
  }
}
