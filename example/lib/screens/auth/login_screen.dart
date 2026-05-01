import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final ok = await auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.error ?? 'Login failed')));
    }
  }

  Future<void> _googleLogin() async {
    final auth = context.read<AuthService>();
    final ok = await auth.signInWithGoogle();
    if (!ok && mounted && auth.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo / Title
                const Icon(Icons.local_shipping_rounded,
                    size: 72, color: Color(0xFF1A73E8)),
                const SizedBox(height: 16),
                const Text('DropShip Navigator',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A73E8))),
                const Text('Sign in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 48),
                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                // Password
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showResetDialog(context),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                // Sign In Button
                ElevatedButton(
                  onPressed: auth.loading ? null : _login,
                  child: auth.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In',
                          style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                // Divider
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),
                // Google Sign-In
                OutlinedButton.icon(
                  onPressed: auth.loading ? null : _googleLogin,
                  icon: const Icon(Icons.g_mobiledata_rounded,
                      size: 28, color: Color(0xFFDB4437)),
                  label: const Text('Continue with Google',
                      style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),
                // Register Link
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text('Sign Up',
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

  void _showResetDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
              labelText: 'Email address',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final ok = await context
                    .read<AuthService>()
                    .sendPasswordReset(ctrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok
                          ? 'Reset email sent!'
                          : 'Failed to send reset email.')));
                }
              },
              child: const Text('Send')),
        ],
      ),
    );
  }
}
