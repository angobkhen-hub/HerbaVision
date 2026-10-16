import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  // Web uses localhost, the Android emulator uses 10.0.2.2 (its alias for your
  // PC's localhost). For a real phone, pass your laptop's address when running:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000',
  );

  static Future<Map<String, dynamic>> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'display_name': displayName,
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Registration failed');
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Login failed');
    }
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