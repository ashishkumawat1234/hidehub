import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/lock_screen.dart';

void main() {
  runApp(const HideHubApp());
}

class HideHubApp extends StatelessWidget {
  const HideHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HideHub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isFirstTime = await _authService.isFirstTime();

      setState(() {
        _isFirstTime = isFirstTime;
        _isLoading = false;
      });
    } catch (e) {
      // If there's an error, assume it's first time
      setState(() {
        _isFirstTime = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    // If it's first time, show PIN setup screen
    if (_isFirstTime) {
      return const PinSetupScreen();
    }

    // Otherwise, show lock screen
    return const LockScreen();
  }
}
