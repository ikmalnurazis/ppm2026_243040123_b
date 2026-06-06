import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'model/catatan.dart';

// Kelas Custom Exception untuk menangkap error dari server
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static const String baseUrl = 'https://besab-production.up.railway.app/api';
  static const String apiKey = '8f38b5fbf0bc437285f2c62ed6e447eab56f78c8f95239a7';
  static const Duration timeoutDuration = Duration(seconds: 10);

  static Map<String, String> get headers => {
    'X-API-Key': apiKey,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // 1. GET ALL DATA
  static Future<List<Catatan>> getAll() async {
    final res = await _sendRequest(() => http.get(
      Uri.parse('$baseUrl/catatan'),
      headers: headers,
    ));
    final data = jsonDecode(res.body);
    return (data['data'] as List).map((e) => Catatan.fromJson(e)).toList();
  }

  // 2. INSERT / POST DATA
  static Future<Catatan> insert(Catatan c) async {
    final res = await _sendRequest(() => http.post(
      Uri.parse('$baseUrl/catatan'),
      headers: headers,
      body: jsonEncode(c.toJson()),
    ));
    final data = jsonDecode(res.body);
    return Catatan.fromJson(data['data']);
  }

  // 3. UPDATE / PUT DATA
  static Future<Catatan> update(Catatan c) async {
    final res = await _sendRequest(() => http.put(
      Uri.parse('$baseUrl/catatan/${c.id}'),
      headers: headers,
      body: jsonEncode(c.toJson()),
    ));
    final data = jsonDecode(res.body);
    return Catatan.fromJson(data['data']);
  }

  // 4. DELETE DATA
  static Future<void> delete(int id) async {
    await _sendRequest(() => http.delete(
      Uri.parse('$baseUrl/catatan/$id'),
      headers: headers,
    ));
  }

  // ===== HELPER UNTUK HANDLING ERROR JARINGAN & TIMEOUT =====
  static Future<http.Response> _sendRequest(Future<http.Response> Function() req) async {
    try {
      final response = await req().timeout(timeoutDuration);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw ApiException(response.statusCode, _extractMessage(response));
    } on SocketException {
      throw ApiException(0, 'Tidak ada koneksi internet.');
    } on TimeoutException {
      throw ApiException(0, 'Server tidak merespons (timeout).');
    }
  }

  static String _extractMessage(http.Response res) {
    try {
      final m = jsonDecode(res.body);
      return m['message'] ?? 'HTTP ${res.statusCode}';
    } catch (_) {
      return 'HTTP ${res.statusCode}';
    }
  }
}