import 'package:flutter/material.dart';
import 'package:gamewala_repairs/services/api_service.dart';
import 'package:gamewala_repairs/widgets/status_chip.dart';

class AllRepairsScreen extends StatefulWidget {
  const AllRepairsScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<AllRepairsScreen> createState() => _AllRepairsScreenState();
}

class _AllRepairsScreenState extends State<AllRepairsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _sortField = 'DateSubmitted';
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.getAll();
      final data = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() => _rows = data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sortBy(String field) {
    setState(() {
      if (_sortField == field) {
        _ascending = !_ascending;
      } else {
        _sortField = field;
        _ascending = true;
      }
      _rows.sort((a, b) {
        final va = '${a[field] ?? ''}';
        final vb = '${b[field] ?? ''}';
        final cmp = va.compareTo(vb);
        return _ascending ? cmp : -cmp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Repairs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  _headerRow(),
                  for (final row in _rows) _dataRow(row),
                ],
              ),
            ),
    );
  }

  Widget _headerRow() {
    Widget headerCell(String label, String field) => InkWell(
          onTap: () => _sortBy(field),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_sortField == field)
                Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
            ]),
          ),
        );

    return Material(
      elevation: 1,
      child: Row(
        children: [
          Expanded(child: headerCell('RepairID', 'RepairID')),
          Expanded(child: headerCell('Customer', 'CustomerName')),
          Expanded(child: headerCell('Product', 'Product')),
          Expanded(child: headerCell('Status', 'Status')),
          Expanded(child: headerCell('Assigned', 'AssignedTo')),
          Expanded(child: headerCell('ETA', 'EstimatedTime')),
        ],
      ),
    );
  }

  Widget _dataRow(Map<String, dynamic> row) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(child: Text('${row['RepairID']}')),
            Expanded(child: Text('${row['CustomerName']}')),
            Expanded(child: Text('${row['Product']}')),
            Expanded(child: StatusChip(status: '${row['Status']}')),
            Expanded(child: Text('${row['AssignedTo']}')),
            Expanded(child: Text('${row['EstimatedTime']}')),
          ],
        ),
      ),
    );
  }
}
