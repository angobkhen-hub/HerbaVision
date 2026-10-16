import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_state.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authState = context.read<AuthState>();
      await authState.checkExistingSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        switch (authState.status) {
          case AuthStatus.checking:
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.eco, size: 64, color: Color(0xFF2F7A4F)),
                    SizedBox(height: 16),
                    Text(
                      'HerbaVision',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 24),
                    CircularProgressIndicator(color: Color(0xFF2F7A4F)),
                  ],
                ),
              ),
            );
          case AuthStatus.loggedIn:
          case AuthStatus.guest:
            return const DashboardScreen();
          case AuthStatus.loggedOut:
            return const LoginScreen();
        }
      },
    );
  }
}