import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/auth_service.dart';
import '../widgets/pin_input_widget.dart';
import 'home_screen.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final AuthService _authService = AuthService();
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _biometricAvailable = false;
  bool _enableBiometric = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await _authService.isBiometricAvailable();
    final biometrics = await _authService.getAvailableBiometrics();

    setState(() {
      _biometricAvailable = isAvailable;
      _availableBiometrics = biometrics;
    });
  }

  void _onPinChanged(String pin) {
    setState(() {
      if (_isConfirming) {
        _confirmPin = pin;
      } else {
        _pin = pin;
      }
    });

    if (pin.length == 4) {
      if (_isConfirming) {
        _confirmPinSetup();
      } else {
        _proceedToConfirmation();
      }
    }
  }

  void _proceedToConfirmation() {
    setState(() {
      _isConfirming = true;
      _confirmPin = '';
    });
  }

  Future<void> _confirmPinSetup() async {
    if (_pin == _confirmPin) {
      await _authService.setPin(_pin);

      if (_enableBiometric && _biometricAvailable) {
        await _authService.setBiometricEnabled(true);
      }

      await _authService.setFirstTimeComplete();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      _showErrorAndReset();
    }
  }

  void _showErrorAndReset() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PINs do not match. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );

    setState(() {
      _pin = '';
      _confirmPin = '';
      _isConfirming = false;
    });
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
                  _isConfirming ? 'Confirm your PIN' : 'Set up your PIN',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),

                const SizedBox(height: 32),

                // PIN Input
                PinInputWidget(
                  onPinChanged: _onPinChanged,
                  currentPin: _isConfirming ? _confirmPin : _pin,
                ),

                const SizedBox(height: 32),

                // Biometric option (only show on first setup)
                if (_biometricAvailable && !_isConfirming) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _availableBiometrics.contains(BiometricType.face)
                              ? Icons.face
                              : Icons.fingerprint,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Enable ${_getBiometricTypeText()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Switch(
                          value: _enableBiometric,
                          onChanged: (value) {
                            setState(() {
                              _enableBiometric = value;
                            });
                          },
                          activeThumbColor: Colors.deepPurple,
                          activeTrackColor: Colors.deepPurple.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Instructions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _isConfirming
                        ? 'Re-enter your 4-digit PIN'
                        : 'Create a 4-digit PIN to secure your app',
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
