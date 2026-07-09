import 'dart:ui';

import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  AuthService();

  static const _loginTimeKey = 'last_login_ms';
  static const _guestModeKey = 'is_guest_mode';
  static const _sessionDays = 7;

  AGCUser? _currentUser;
  bool _isInitialized = false;
  bool _isGuestMode = false;

  AGCUser? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isSignedIn => _currentUser != null || _isGuestMode;
  bool get isGuestMode => _isGuestMode;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuestMode = prefs.getBool(_guestModeKey) ?? false;

    if (!_isGuestMode) {
      _currentUser = await AGCAuth.instance.currentUser;
      if (_currentUser != null && !await isSessionValid()) {
        await AGCAuth.instance.signOut();
        _currentUser = null;
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> isSessionValid() async {
    if (_currentUser == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getInt(_loginTimeKey);
    if (lastLogin == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastLogin;
    return elapsed < const Duration(days: _sessionDays).inMilliseconds;
  }

  Future<void> signIn({required String email, required String password}) async {
    final credential = EmailAuthProvider.credentialWithPassword(
      email,
      password,
    );
    try {
      final result = await AGCAuth.instance.signIn(credential);
      _currentUser = result.user;
    } catch (error) {
      final message = error.toString();
      if (!message.contains('InstantiationException')) {
        rethrow;
      }
      _currentUser = await AGCAuth.instance.currentUser;
      if (_currentUser == null) {
        rethrow;
      }
    }
    await _saveLoginTime();
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String verifyCode,
  }) async {
    try {
      final result = await AGCAuth.instance.createEmailUser(
        EmailUser(email, verifyCode, password),
      );
      _currentUser = result.user;
      await _saveLoginTime();
      notifyListeners();
    } catch (error) {
      final message = error.toString();
      if (!message.contains('InstantiationException')) {
        rethrow;
      }
      try {
        await signIn(email: email, password: password);
      } catch (_) {
        _currentUser = await AGCAuth.instance.currentUser;
        if (_currentUser == null) {
          rethrow;
        }
        await _saveLoginTime();
        notifyListeners();
      }
    }
  }

  Future<void> requestEmailVerifyCode(String email) async {
    try {
      await AGCAuth.instance.requestVerifyCodeWithEmail(
        email,
        VerifyCodeSettings(
          VerifyCodeAction.registerLogin,
          locale: const Locale('zh', 'CN'),
          sendInterval: 60,
        ),
      );
    } catch (error) {
      final message = error.toString();
      if (!message.contains('InstantiationException')) {
        rethrow;
      }
    }
  }

  Future<void> signOut() async {
    await AGCAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginTimeKey);
    _currentUser = null;
    notifyListeners();
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);
    _isGuestMode = true;
    notifyListeners();
  }

  Future<void> exitGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
    _isGuestMode = false;
    notifyListeners();
  }

  Future<void> _saveLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_loginTimeKey, DateTime.now().millisecondsSinceEpoch);
  }
}
