import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // Load user profile once authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            authService.loadCurrentUser();
          });
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
