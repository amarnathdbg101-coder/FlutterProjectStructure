import 'package:flutter/material.dart';

/// Clean model definition for AI Study Workspace modules
class StudyEngineItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final String badge;
  final String category;

  const StudyEngineItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    this.badge = 'Active',
    this.category = 'all',
  });
}
