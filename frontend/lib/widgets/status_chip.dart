import 'package:flutter/material.dart';

Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'received':
      return Colors.red;
    case 'in progress':
      return Colors.amber;
    case 'completed':
      return Colors.green;
    case 'delivered':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      side: BorderSide(color: color),
    );
  }
}
