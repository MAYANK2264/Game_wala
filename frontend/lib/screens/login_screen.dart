import 'package:flutter/material.dart';
import 'package:gamewala_repairs/services/api_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin, required this.api});
  final void Function(String role, String? actorEmail, String? ownerEmail) onLogin;
  final ApiService api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _role = 'Employee';
  final _ownerEmail = TextEditingController();
  GoogleSignInAccount? _account;

  @override
  void dispose() {
    _ownerEmail.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final googleSignIn = GoogleSignIn(scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/spreadsheets'
    ]);
    try {
      _account = await googleSignIn.signIn();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e'), backgroundColor: Colors.red),
      );
    }
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.account_circle),
                  label: Text(_account?.email ?? 'Sign in with Google'),
                ),
              ),
              if (_role == 'Owner') TextField(
                controller: _ownerEmail,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Owner Email (for Google Sheets)',
                  hintText: 'owner@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_role == 'Owner' && _ownerEmail.text.trim().isNotEmpty) {
                      // Setup owner's Google Sheet
                      try {
                        final result = await widget.api.setupOwner(ownerEmail: _ownerEmail.text.trim());
                        if (result['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Setup completed: ${result['message']}')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Setup failed: ${result['error']}')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Setup error: $e')),
                        );
                      }
                    }
                    final email = _account?.email;
                    if (_role == 'Employee' && email != null && email.isNotEmpty) {
                      try { await widget.api.requestAccess(email: email); } catch (_) {}
                    }
                    widget.onLogin(_role, email, _ownerEmail.text.trim().isEmpty ? null : _ownerEmail.text.trim());
                  },
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
