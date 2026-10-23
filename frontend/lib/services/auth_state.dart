import 'package:flutter/material.dart';
import 'api_service.dart';

enum AuthStatus { checking, loggedOut, loggedIn, guest }

/// Why a login or registration attempt failed. The screens use this to show the
/// right message and the right next step (Retry, Log in instead, ...).
enum AuthFailure {
  invalidCredentials,
  emailTaken,
  noConnection,
  timeout,
  server,
  validation,
  unknown,
}

/// The outcome of [AuthState.login] / [AuthState.register].
class AuthResult {
  final bool success;
  final AuthFailure? failure;
  final String message;

  const AuthResult.ok()
      : success = true,
        failure = null,
        message = '';

  const AuthResult.failed(this.failure, this.message) : success = false;

  /// True when trying again can help, because the problem is the connection or
  /// the server and not what the user typed.
  bool get canRetry =>
      failure == AuthFailure.noConnection ||
      failure == AuthFailure.timeout ||
      failure == AuthFailure.server;
}

class AuthState extends ChangeNotifier {
  AuthStatus _status = AuthStatus.checking;
  String? _userName;
  String? _userEmail;
  String? _token;

  // A successful login whose session has not been started yet. The login screen
  // uses this to show "Login successful" before the app moves to the dashboard.
  Map<String, dynamic>? _pendingLogin;

  AuthStatus get status => _status;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get token => _token;
  bool get isGuest => _status == AuthStatus.guest;
  bool get isLoggedIn => _status == AuthStatus.loggedIn;

  /// The display name from a login that succeeded but has not started yet.
  String? get pendingUserName {
    final user = _pendingLogin?['user'];
    return user is Map ? user['display_name'] as String? : null;
  }

  // Called on app start to check if a session already exists.
  // For now this just simulates a quick check; wire this to real
  // session/token persistence (e.g. shared_preferences) later.
  Future<void> checkExistingSession() async {
    await Future.delayed(const Duration(milliseconds: 600));
    _status = AuthStatus.loggedOut;
    notifyListeners();
  }

  /// Logs in. With [startSession] false the server answer is kept aside and the
  /// app stays on the login screen until [completeLogin] is called.
  Future<AuthResult> login(
    String email,
    String password, {
    bool startSession = true,
  }) async {
    try {
      final data = await ApiService.login(email: email, password: password);
      if (startSession) {
        _startSession(data);
      } else {
        _pendingLogin = data;
      }
      return const AuthResult.ok();
    } catch (e) {
      return _failureFrom(e, isRegister: false);
    }
  }

  /// Starts the session held back by `login(..., startSession: false)`.
  void completeLogin() {
    final data = _pendingLogin;
    if (data == null) return;
    _pendingLogin = null;
    _startSession(data);
  }

  Future<AuthResult> register(String name, String email, String password) async {
    try {
      final data = await ApiService.register(
        displayName: name,
        email: email,
        password: password,
      );
      _startSession(data);
      return const AuthResult.ok();
    } catch (e) {
      return _failureFrom(e, isRegister: true);
    }
  }

  void _startSession(Map<String, dynamic> data) {
    _token = data['access_token'];
    _userEmail = data['user']['email'];
    _userName = data['user']['display_name'];
    _status = AuthStatus.loggedIn;
    notifyListeners();
  }

  /// Turns an error from the API layer into a message the user can act on.
  AuthResult _failureFrom(Object error, {required bool isRegister}) {
    if (error is ApiTimeoutException) {
      return const AuthResult.failed(
        AuthFailure.timeout,
        'The server took too long to respond. Please try again.',
      );
    }
    if (error is ApiConnectionException) {
      return const AuthResult.failed(
        AuthFailure.noConnection,
        "Can't reach the server. Check your connection and try again.",
      );
    }
    if (error is ApiException) {
      final code = error.statusCode;
      if (code == 401) {
        return const AuthResult.failed(
          AuthFailure.invalidCredentials,
          'Incorrect email or password. Check them and try again.',
        );
      }
      if (code == 400 && isRegister) {
        return const AuthResult.failed(
          AuthFailure.emailTaken,
          'This email is already registered.',
        );
      }
      if (code == 422) {
        return const AuthResult.failed(
          AuthFailure.validation,
          'Some details look invalid. Please check them and try again.',
        );
      }
      if (code != null && code >= 500) {
        return const AuthResult.failed(
          AuthFailure.server,
          'Something went wrong on our side. Please try again.',
        );
      }
    }
    return const AuthResult.failed(
      AuthFailure.unknown,
      'Something went wrong. Please try again.',
    );
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
    _pendingLogin = null;
    _status = AuthStatus.loggedOut;
    notifyListeners();
  }
}