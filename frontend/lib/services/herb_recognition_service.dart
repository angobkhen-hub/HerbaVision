import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/herb_scan.dart';
import 'api_service.dart';

/// Thrown when the model isn't sure which herb this is. That usually means the
/// plant isn't one of the herbs in the database yet.
class PlantNotRecognizedException implements Exception {
  final String message;
  const PlantNotRecognizedException([
    this.message = "We couldn't identify this plant. It may not be in our "
        "database yet.",
  ]);

  @override
  String toString() => message;
}

/// Identifies a leaf by sending the photo to the backend's POST /recognize
/// endpoint, which runs the trained model.
///
/// Works on web and mobile: it takes the photo's raw bytes (no dart:io File),
/// for example `await pickedFile.readAsBytes()` with image_picker.
class HerbRecognitionService {
  Future<HerbScan> identifyLeaf(
    Uint8List bytes, {
    String filename = 'leaf.jpg',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/recognize'),
    )..files.add(http.MultipartFile.fromBytes('image', bytes, filename: filename));

    http.Response response;
    try {
      // The first request after the server starts is slower (the model loads).
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw Exception('The server took too long to respond. Please try again.');
    } catch (_) {
      throw Exception('Cannot reach the server. Check your connection and try again.');
    }

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Unexpected response from the server.');
    }

    if (response.statusCode != 200) {
      final detail = data is Map ? data['detail'] : null;
      throw Exception('${detail ?? 'Recognition failed'}');
    }

    // The model always picks one of its known herbs, so a low score means
    // "not sure" rather than a real match.
    if (data['confident'] != true) {
      throw const PlantNotRecognizedException();
    }

    return HerbScan(
      name: data['name'] as String,
      latinName: data['latin_name'] as String,
      confidence: (data['confidence'] as num).round(),
    );
  }
}