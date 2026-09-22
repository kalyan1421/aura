import 'package:flutter/material.dart';

/// One check-in (`/history/:id`): view, edit within 24 h, delete.
/// Placeholder route target — the check-in history work fills it in.
class CheckInDetailScreen extends StatelessWidget {
  const CheckInDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => const Scaffold();
}
