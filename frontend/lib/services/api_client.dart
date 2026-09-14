import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/task.dart';
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

  /// Fetches active tasks for the authenticated user
  Future<List<Task>> getTasks() async {
    final headers = await _getHeaders();
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/tasks'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>;
      return list.map((item) => Task.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception(
        'Failed to fetch tasks: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Creates a new task
  Future<Task> createTask({
    required String title,
    required DateTime deadline,
    required int importance,
    required int estimatedMinutes,
  }) async {
    final headers = await _getHeaders();
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/tasks'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'deadline': deadline.toIso8601String(),
        'importance': importance,
        'estimatedMinutes': estimatedMinutes,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Task.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      throw Exception(
        'Failed to create task: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Updates task status (e.g. NOT_STARTED -> IN_PROGRESS -> COMPLETED)
  Future<Task> updateTaskStatus(int taskId, String newStatus) async {
    final headers = await _getHeaders();
    final response = await _httpClient.patch(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: headers,
      body: jsonEncode({
        'status': newStatus,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Task.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      throw Exception(
        'Failed to update task status: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
