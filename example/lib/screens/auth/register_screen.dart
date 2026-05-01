import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final ok = await auth.signUpWithEmail(
        _emailCtrl.text.trim(), _passCtrl.text, _nameCtrl.text.trim());
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.error ?? 'Sign up failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add_alt_1_rounded,
                    size: 64, color: Color(0xFF1A73E8)),
                const SizedBox(height: 24),
                _field(_nameCtrl, 'Full Name', Icons.person_outlined,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your name' : null),
                const SizedBox(height: 16),
                _field(_emailCtrl, 'Email', Icons.email_outlined,
                    type: TextInputType.emailAddress,
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Enter a valid email' : null),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  validator: (v) =>
                      v != _passCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: auth.loading ? null : _register,
                  child: auth.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Already have an account? '),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('Sign In',
                        style: TextStyle(
                            color: Color(0xFF1A73E8),
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      validator: validator,
    );
  }
}
