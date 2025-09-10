import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final void Function(String role, String? actorName) onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _role = 'Employee';
  final _actor = TextEditingController();

  @override
  void dispose() {
    _actor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GameWala Repairs',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'Owner', child: Text('Owner')),
                  DropdownMenuItem(value: 'Employee', child: Text('Employee')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'Employee'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Select Role',
                ),
              ),
              const SizedBox(height: 12),
              if (_role == 'Employee') TextField(
                controller: _actor,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Your Name (must match AssignedTo)',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => widget.onLogin(_role, _actor.text.trim().isEmpty ? null : _actor.text.trim()),
                  icon: const Icon(Icons.login),
                  label: const Text('Continue'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
