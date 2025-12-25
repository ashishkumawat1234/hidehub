import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _pinKey = 'user_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _isFirstTimeKey = 'is_first_time';

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if it's first time opening the app
  Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstTimeKey) ?? true;
  }

  // Set first time flag to false
  Future<void> setFirstTimeComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstTimeKey, false);
  }

  // Hash PIN for security
  String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Set PIN
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hashedPin = _hashPin(pin);
    await prefs.setString(_pinKey, hashedPin);
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    if (storedPin == null) return false;

    final hashedPin = _hashPin(pin);
    return hashedPin == storedPin;
  }

  // Check if PIN is set
  Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) != null;
  }

  // Check if biometric is available
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Enable/Disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  // Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // Authenticate with biometric
  Future<bool> authenticateWithBiometric() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access HideHub',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return isAuthenticated;
    } catch (e) {
      return false;
    }
  }

  // Reset all authentication data
  Future<void> resetAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_biometricEnabledKey);
    await prefs.setBool(_isFirstTimeKey, true);
  }
}
