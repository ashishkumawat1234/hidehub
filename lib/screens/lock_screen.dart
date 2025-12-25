import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/auth_service.dart';
import '../widgets/pin_input_widget.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  String _pin = '';
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  int _failedAttempts = 0;
  bool _isLocked = false;
  DateTime? _lockUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeBiometric();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Try biometric authentication when app comes to foreground
      if (_biometricEnabled && _biometricAvailable) {
        _authenticateWithBiometric();
      }
    }
  }

  Future<void> _initializeBiometric() async {
    final isEnabled = await _authService.isBiometricEnabled();
    final isAvailable = await _authService.isBiometricAvailable();
    final biometrics = await _authService.getAvailableBiometrics();

    setState(() {
      _biometricEnabled = isEnabled;
      _biometricAvailable = isAvailable;
      _availableBiometrics = biometrics;
    });

    // Auto-trigger biometric authentication if enabled
    if (_biometricEnabled && _biometricAvailable) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _authenticateWithBiometric();
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_isLocked) return;

    final isAuthenticated = await _authService.authenticateWithBiometric();
    if (isAuthenticated && mounted) {
      _navigateToHome();
    }
  }

  void _onPinChanged(String pin) {
    setState(() {
      _pin = pin;
    });

    if (pin.length == 4) {
      _verifyPin();
    }
  }

  Future<void> _verifyPin() async {
    if (_isLocked) {
      _showLockedMessage();
      return;
    }

    final isCorrect = await _authService.verifyPin(_pin);

    if (isCorrect) {
      _navigateToHome();
    } else {
      _handleFailedAttempt();
    }
  }

  void _handleFailedAttempt() {
    setState(() {
      _failedAttempts++;
      _pin = '';
    });

    if (_failedAttempts >= 5) {
      _lockApp();
    } else {
      _showErrorMessage();
    }
  }

  void _lockApp() {
    setState(() {
      _isLocked = true;
      _lockUntil = DateTime.now().add(const Duration(minutes: 5));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Too many failed attempts. App locked for 5 minutes.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );

    // Auto-unlock after 5 minutes
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted) {
        setState(() {
          _isLocked = false;
          _failedAttempts = 0;
          _lockUntil = null;
        });
      }
    });
  }

  void _showErrorMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Incorrect PIN. ${5 - _failedAttempts} attempts remaining.',
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLockedMessage() {
    final remaining = _lockUntil?.difference(DateTime.now()).inMinutes ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('App is locked. Try again in $remaining minutes.'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  String _getBiometricTypeText() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris';
    }
    return 'Biometric';
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return Icons.remove_red_eye;
    }
    return Icons.security;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Title
                const Text(
                  'HideHub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  _isLocked ? 'App Locked' : 'Enter your PIN',
                  style: TextStyle(
                    color: _isLocked ? Colors.red : Colors.grey[400],
                    fontSize: 16,
                  ),
                ),

                if (_isLocked && _lockUntil != null) ...[
                  const SizedBox(height: 8),
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(seconds: 1)),
                    builder: (context, snapshot) {
                      final remaining = _lockUntil!.difference(DateTime.now());
                      if (remaining.isNegative) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        'Try again in ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(color: Colors.red[300], fontSize: 14),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // PIN Input
                PinInputWidget(
                  onPinChanged: _onPinChanged,
                  currentPin: _pin,
                  enabled: !_isLocked,
                ),

                const SizedBox(height: 32),

                // Biometric button
                if (_biometricEnabled && _biometricAvailable && !_isLocked) ...[
                  GestureDetector(
                    onTap: _authenticateWithBiometric,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getBiometricIcon(), color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          Text(
                            'Use ${_getBiometricTypeText()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Failed attempts indicator
                if (_failedAttempts > 0 && !_isLocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Failed attempts: $_failedAttempts/5',
                      style: TextStyle(color: Colors.red[300], fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Instructions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _isLocked
                        ? 'App is temporarily locked due to multiple failed attempts'
                        : 'Enter your 4-digit PIN to unlock',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
