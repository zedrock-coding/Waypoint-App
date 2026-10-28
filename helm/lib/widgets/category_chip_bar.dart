import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/hive_models.dart' as hive_model;

class CategoryChipBar extends StatelessWidget {
  final String? selectedCategoryId;
  final Function(String?) onSelected;

  const CategoryChipBar({
    super.key,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder(
      valueListenable: Hive.box<hive_model.Category>('categories').listenable(),
      builder: (context, Box<hive_model.Category> box, _) {
        final categories = box.values.toList();
        
        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: selectedCategoryId == null,
                    onSelected: (selected) {
                      if (selected) onSelected(null);
                    },
                    selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: colorScheme.primary,
                  ),
                );
              }
              
              final category = categories[index - 1];
              final String catId = category.id ?? '';
              final isSelected = selectedCategoryId == catId;
              
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(category.name ?? 'Unnamed'),
                  selected: isSelected,
                  onSelected: (selected) {
                    onSelected(selected ? catId : null);
                  },
                  selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                  checkmarkColor: colorScheme.primary,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
