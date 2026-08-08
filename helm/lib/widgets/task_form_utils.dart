import 'package:flutter/material.dart';
import '../add_event_page.dart';
import '../models/unified_task.dart';

void showAddTaskForm(BuildContext context, {UnifiedTask? taskToEdit, String? initialCommunityId, String? category}) {
  final double width = MediaQuery.of(context).size.width;

  if (width < 800) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventPage(
          taskToEdit: taskToEdit,
          initialCommunityId: initialCommunityId, 
          initialCategory: category,
        ),
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: AddEventPage(
          taskToEdit: taskToEdit,
          initialCommunityId: initialCommunityId, 
          initialCategory: category,
          isDialog: true,
        ),
      ),
    );
  }
}
