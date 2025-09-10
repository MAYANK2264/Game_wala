import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gamewala_repairs/services/api_service.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

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

  List<String> _products = const [
    'PlayStation 5', 'PlayStation 4', 'Xbox Series X', 'Xbox One', 'Nintendo Switch', 'Accessory'
  ];
  List<String> _assignees = const [
    'Unassigned', 'Ravi', 'Aman', 'Priya', 'Kiran'
  ];

  // Voice note
  final _recorder = AudioRecorder();
  String? _voiceFilePath;

  @override
  void initState() {
    super.initState();
    _loadMasters();
  }

  Future<void> _loadMasters() async {
    try {
      final res = await widget.api.getMasters();
      if (res['success'] == true) {
        final m = res['data'] as Map<String, dynamic>;
        final products = (m['products'] as List?)?.cast<String>() ?? _products;
        final employees = (m['employees'] as List?)?.cast<String>() ?? _assignees;
        setState(() {
          _products = products.isNotEmpty ? products : _products;
          _assignees = employees.isNotEmpty ? ['Unassigned', ...employees] : _assignees;
          if (!_products.contains(_product)) _product = _products.first;
          if (!_assignees.contains(_assignedTo)) _assignedTo = _assignees.first;
        });
      }
    } catch (_) {}
  }

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
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleRecord,
                  icon: Icon(_voiceFilePath == null ? Icons.mic : Icons.stop),
                  label: Text(_voiceFilePath == null ? 'Record Voice Note' : 'Stop Recording'),
                ),
                const SizedBox(width: 12),
                if (_voiceFilePath != null)
                  Expanded(child: Text(p.basename(_voiceFilePath!), overflow: TextOverflow.ellipsis)),
              ],
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

  Future<void> _toggleRecord() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied'), backgroundColor: Colors.red),
      );
      return;
    }

    if (await _recorder.isRecording()) {
      final path = await _recorder.stop();
      setState(() => _voiceFilePath = path);
      return;
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
    );
    setState(() => _voiceFilePath = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      String? b64;
      String? filename;
      if (_voiceFilePath != null) {
        final f = File(_voiceFilePath!);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          b64 = base64Encode(bytes);
          final ext = p.extension(_voiceFilePath!).isNotEmpty ? p.extension(_voiceFilePath!) : '.m4a';
          filename = 'voice_note$ext';
        }
      }

      final res = await widget.api.addRepair(
        customerName: _name.text.trim(),
        phone: _phone.text.trim(),
        product: _product,
        issue: _issue.text.trim(),
        estimatedTime: _estimated.text.trim(),
        assignedTo: _assignedTo,
        notes: _notes.text.trim(),
        voiceNoteBase64: b64,
        voiceNoteFilename: filename,
      );
      if (res['success'] == true) {
        final id = res['repairId'];
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added. RepairID: $id'), backgroundColor: Colors.green),
        );
        _formKey.currentState!.reset();
        setState(() { _voiceFilePath = null; _product = _products.first; _assignedTo = _assignees.first; });
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
