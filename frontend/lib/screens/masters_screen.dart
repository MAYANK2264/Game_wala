import 'package:flutter/material.dart';
import 'package:gamewala_repairs/services/api_service.dart';

class MastersScreen extends StatefulWidget {
  const MastersScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends State<MastersScreen> {
  final _employeeCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  bool _loading = true;
  List<String> _employees = [];
  List<String> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _employeeCtrl.dispose();
    _productCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.api.getMasters();
      if (res['success'] == true) {
        final m = res['data'] as Map<String, dynamic>;
        setState(() {
          _employees = (m['employees'] as List?)?.cast<String>() ?? [];
          _products = (m['products'] as List?)?.cast<String>() ?? [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(String type, TextEditingController ctrl) async {
    final value = ctrl.text.trim();
    if (value.isEmpty) return;
    final res = await widget.api.addMaster(type: type, value: value, role: 'Owner');
    if (!mounted) return;
    if (res['success'] == true) {
      ctrl.clear();
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${res['error']}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Masters')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Employees', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _employeeCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Add employee name'))),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => _add('employee', _employeeCtrl), child: const Text('Add')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final e in _employees) ListTile(title: Text(e)),
                  const Divider(),
                  const Text('Products', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _productCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Add product'))),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => _add('product', _productCtrl), child: const Text('Add')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final p in _products) ListTile(title: Text(p)),
                ],
              ),
            ),
    );
  }
}
