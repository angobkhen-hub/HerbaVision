import 'package:flutter/material.dart';
import 'api_service.dart';

enum AuthStatus { checking, loggedOut, loggedIn, guest }

class AuthState extends ChangeNotifier {
  AuthStatus _status = AuthStatus.checking;
  String? _userName;
  String? _userEmail;
  String? _token;

  AuthStatus get status => _status;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get token => _token;
  bool get isGuest => _status == AuthStatus.guest;
  bool get isLoggedIn => _status == AuthStatus.loggedIn;

  // Called on app start to check if a session already exists.
  // For now this just simulates a quick check; wire this to real
  // session/token persistence (e.g. shared_preferences) later.
  Future<void> checkExistingSession() async {
    await Future.delayed(const Duration(milliseconds: 600));
    _status = AuthStatus.loggedOut;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final data = await ApiService.login(email: email, password: password);

      _token = data['access_token'];
      _userEmail = data['user']['email'];
      _userName = data['user']['display_name'];
      _status = AuthStatus.loggedIn;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      final data = await ApiService.register(
        displayName: name,
        email: email,
        password: password,
      );

      _token = data['access_token'];
      _userEmail = data['user']['email'];
      _userName = data['user']['display_name'];
      _status = AuthStatus.loggedIn;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  void continueAsGuest() {
    _userName = 'Guest';
    _userEmail = null;
    _status = AuthStatus.guest;
    notifyListeners();
  }

  void logout() {
    _userName = null;
    _userEmail = null;
    _token = null;
    _status = AuthStatus.loggedOut;
    notifyListeners();
  }
}