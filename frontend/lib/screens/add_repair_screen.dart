import 'package:flutter/material.dart';
import 'package:gamewala_repairs/services/api_service.dart';

class AddRepairScreen extends StatefulWidget {
  const AddRepairScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<AddRepairScreen> createState() => _AddRepairScreenState();
}

class _AddRepairScreenState extends State<AddRepairScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _issue = TextEditingController();
  final _estimated = TextEditingController();
  final _notes = TextEditingController();
  String _product = 'PlayStation 5';
  String _assignedTo = 'Unassigned';
  bool _loading = false;

  final _products = const [
    'PlayStation 5', 'PlayStation 4', 'Xbox Series X', 'Xbox One', 'Nintendo Switch', 'Accessory'
  ];
  final _assignees = const [
    'Unassigned', 'Ravi', 'Aman', 'Priya', 'Kiran'
  ];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _issue.dispose();
    _estimated.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Repair')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final digits = RegExp(r'^\d{6,15}$');
                if (!digits.hasMatch(v.trim())) return '6-15 digit number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _product,
              items: _products.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _product = v ?? _product),
              decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _issue,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Issue', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _estimated,
              decoration: const InputDecoration(labelText: 'Estimated Time', border: OutlineInputBorder(), hintText: 'e.g., 2 days'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _assignedTo,
              items: _assignees.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _assignedTo = v ?? _assignedTo),
              decoration: const InputDecoration(labelText: 'Assigned To', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.check),
                label: Text(_loading ? 'Submitting...' : 'Submit'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await widget.api.addRepair(
        customerName: _name.text.trim(),
        phone: _phone.text.trim(),
        product: _product,
        issue: _issue.text.trim(),
        estimatedTime: _estimated.text.trim(),
        assignedTo: _assignedTo,
        notes: _notes.text.trim(),
      );
      if (res['success'] == true) {
        final id = res['repairId'];
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added. RepairID: $id'), backgroundColor: Colors.green),
        );
        _formKey.currentState!.reset();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${res['error']}'), backgroundColor: Colors.red),
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
