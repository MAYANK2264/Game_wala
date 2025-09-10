import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.role, required this.onNavigate});
  final String role; // 'Owner' or 'Employee'
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context) {
    final isOwner = role == 'Owner';
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard ($role)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _bigButton(context, Icons.add_box, 'Add New Repair', () => onNavigate('/add')),
            _bigButton(context, Icons.sync, 'Update Status', () => onNavigate('/update')),
            _bigButton(context, Icons.search, 'Search Repair', () => onNavigate('/search')),
            if (isOwner) _bigButton(context, Icons.list, 'All Repairs', () => onNavigate('/all')),
            if (isOwner) _bigButton(context, Icons.settings, 'Manage Masters', () => onNavigate('/masters')),
          ],
        ),
      ),
    );
  }

  Widget _bigButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 12),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
