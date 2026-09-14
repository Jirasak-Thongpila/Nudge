import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'auth_service.dart';

class ApiClient {
  final String baseUrl;
  final AuthService authService;
  final http.Client _httpClient;

  ApiClient({
    this.baseUrl = 'http://localhost:3000',
    AuthService? authService,
    http.Client? httpClient,
  })  : authService = authService ?? AuthService(),
        _httpClient = httpClient ?? http.Client();

  Future<Map<String, String>> _getHeaders() async {
    final deviceUuid = await authService.getOrCreateDeviceUuid();
    return {
      'Content-Type': 'application/json',
      'x-device-uuid': deviceUuid,
    };
  }

  /// Checks backend liveness
  Future<bool> checkHealth() async {
    try {
      final response = await _httpClient.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches or auto-provisions current user profile via ADR-0001
  Future<User> getCurrentUser() async {
    final headers = await _getHeaders();
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/users/me'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return User.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      throw Exception(
        'Failed to fetch user: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
