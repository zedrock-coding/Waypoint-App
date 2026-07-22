import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/event.dart';
import '../add_event_page.dart';

void showAddTaskForm(BuildContext context, {required Isar isar, Event? eventToEdit, String? category}) {
  final double width = MediaQuery.of(context).size.width;

  if (width < 800) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventPage(
          isar: isar, 
          eventToEdit: eventToEdit, 
          initialCategory: category,
        ),
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: AddEventPage(
          isar: isar, 
          eventToEdit: eventToEdit, 
          initialCategory: category,
          isDialog: true,
        ),
      ),
    );
  }
}
