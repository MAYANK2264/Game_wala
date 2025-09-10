import 'package:flutter/material.dart';
import 'package:gamewala_repairs/services/api_service.dart';
import 'package:gamewala_repairs/widgets/status_chip.dart';

class SearchRepairScreen extends StatefulWidget {
  const SearchRepairScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<SearchRepairScreen> createState() => _SearchRepairScreenState();
}

class _SearchRepairScreenState extends State<SearchRepairScreen> {
  final _repairId = TextEditingController();
  final _customerName = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _repairId.dispose();
    _customerName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Repair')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _repairId,
            decoration: const InputDecoration(labelText: 'RepairID', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customerName,
            decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search),
              label: Text(_loading ? 'Searching...' : 'Search'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
          const SizedBox(height: 16),
          for (final item in _results) _resultTile(item),
        ],
      ),
    );
  }

  Widget _resultTile(Map<String, dynamic> item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['RepairID']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Customer: ${item['CustomerName']}')),
                StatusChip(status: '${item['Status']}'),
              ],
            ),
            Text('Product: ${item['Product']}'),
            Text('Issue: ${item['Issue']}'),
            Text('Estimated: ${item['EstimatedTime']}'),
            Text('Assigned: ${item['AssignedTo']}'),
            if ((item['Notes'] ?? '').toString().isNotEmpty) Text('Notes: ${item['Notes']}'),
          ],
        ),
      ),
    );
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.search(
        repairId: _repairId.text.trim().isEmpty ? null : _repairId.text.trim(),
        customerName: _customerName.text.trim().isEmpty ? null : _customerName.text.trim(),
      );
      final data = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() => _results = data);
      if (!mounted) return;
      if (res['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${res['error'] ?? 'Unknown'}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
