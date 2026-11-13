import 'package:flutter/material.dart';
import '../models/unified_task.dart';
import 'task_creation_drawer.dart';

void showAddTaskForm(
  BuildContext context, {
  UnifiedTask? taskToEdit,
  String? initialCommunityId,
  String? category,
}) {
  showTaskCreationDrawer(context, taskToEdit: taskToEdit);
}
