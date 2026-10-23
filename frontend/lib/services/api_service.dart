import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// An error returned by (or while talking to) the backend.
/// [statusCode] is the HTTP status when the server answered, null otherwise.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// The request never reached the server (offline, wrong address, server stopped).
class ApiConnectionException extends ApiException {
  const ApiConnectionException() : super("Can't reach the server.");
}

/// The server did not answer in time.
class ApiTimeoutException extends ApiException {
  const ApiTimeoutException() : super('The server took too long to respond.');
}

class ApiService {
  // Web uses localhost, the Android emulator uses 10.0.2.2 (its alias for your
  // PC's localhost). For a real phone, pass your laptop's address when running:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000',
  );

  /// How long login/register wait before giving up, so a stuck server never
  /// leaves a spinner running forever.
  static const Duration _authTimeout = Duration(seconds: 15);

  /// DEMO ONLY: slows login/register so the Loading state stays on screen
  /// long enough to see and screenshot. Set to Duration.zero to turn it off.
  static const Duration _demoDelay = Duration(seconds: 25);

  /// DEMO ONLY: true makes every login/register fail with "Can't reach the
  /// server" after the delay, so you can screenshot the Error state and press
  /// Retry without stopping the backend. Set back to false for Success.
  static const bool _demoFail = false;

  static Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(_authTimeout);
    } on TimeoutException {
      throw const ApiTimeoutException();
    } catch (_) {
      throw const ApiConnectionException();
    }
  }

  static String _detail(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
    } catch (_) {}
    return fallback;
  }

  static Future<Map<String, dynamic>> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await Future.delayed(_demoDelay);
    if (_demoFail) throw const ApiConnectionException();
    final response = await _send(http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'display_name': displayName,
        'email': email,
        'password': password,
      }),
    ));

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      _detail(response, 'Registration failed'),
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(_demoDelay);
    if (_demoFail) throw const ApiConnectionException();
    final response = await _send(http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      _detail(response, 'Login failed'),
      statusCode: response.statusCode,
    );
  }

  // ---- Scans ----

  static Future<Map<String, dynamic>> getStats(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/scans/stats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stats');
    }
  }

  static Future<List<dynamic>> getScans(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/scans/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load scans');
    }
  }

  static Future<Map<String, dynamic>> createScan({
    required String token,
    required String plantName,
    String? latinName,
    required double confidence,
    bool savedToLibrary = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/scans/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'plant_name': plantName,
        'latin_name': latinName,
        'confidence': confidence,
        'saved_to_library': savedToLibrary,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to save scan');
    }
  }

  // ---- Herb information (from the leaf_items table) ----

  /// Stored info for one herb (description, benefits, traditional uses,
  /// risks, precautions), or null if it can't be loaded.
  static Future<Map<String, dynamic>?> getHerbInfo(String latinName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/herbs/lookup')
            .replace(queryParameters: {'name': latinName}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Every herb in the database, for the Herb library.
  static Future<List<dynamic>> getHerbs() async {
    final response = await http.get(Uri.parse('$baseUrl/herbs/'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load herbs');
  }

  // ---- Saved herbs (per signed-in user) ----

  /// The signed-in user's saved herbs. Each item contains 'latin_name'.
  static Future<List<dynamic>> getSavedHerbs(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/herbs/saved'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load saved herbs');
  }

  /// Saves or un-saves a herb for the signed-in user.
  static Future<void> setHerbSaved({
    required String token,
    required String latinName,
    required bool saved,
  }) async {
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final response = saved
        ? await http.post(
            Uri.parse('$baseUrl/herbs/saved'),
            headers: headers,
            body: jsonEncode({'latin_name': latinName}),
          )
        : await http.delete(
            Uri.parse('$baseUrl/herbs/saved')
                .replace(queryParameters: {'latin_name': latinName}),
            headers: headers,
          );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to update saved herb');
    }
  }
}