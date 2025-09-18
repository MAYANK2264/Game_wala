import 'package:flutter/material.dart';
import 'package:gamewala_repairs/services/api_service.dart';
import 'package:gamewala_repairs/widgets/status_chip.dart';

class UpdateStatusScreen extends StatefulWidget {
  const UpdateStatusScreen({super.key, required this.api, required this.role, required this.actorEmail});
  final ApiService api;
  final String role;
  final String? actorEmail;

  @override
  State<UpdateStatusScreen> createState() => _UpdateStatusScreenState();
}

class _UpdateStatusScreenState extends State<UpdateStatusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uniqueId = TextEditingController();
  final _notes = TextEditingController();
  String _status = 'Received';
  bool _loading = false;

  final _statuses = const ['Received', 'In Progress', 'Completed', 'Delivered'];

  @override
  void dispose() {
    _repairId.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Status')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Role: ${widget.role}${widget.actorEmail != null ? ' (${widget.actorEmail})' : ''}'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _uniqueId,
              decoration: const InputDecoration(labelText: 'Unique ID', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              items: _statuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
              decoration: const InputDecoration(labelText: 'New Status', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            StatusChip(status: _status),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.save),
                label: Text(_loading ? 'Updating...' : 'Update'),
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
      final res = await widget.api.updateStatus(
        uniqueId: _uniqueId.text.trim(),
        status: _status,
        notes: _notes.text.trim(),
        role: widget.role,
        actorEmail: widget.actorEmail,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated'), backgroundColor: Colors.green),
        );
      } else {
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
