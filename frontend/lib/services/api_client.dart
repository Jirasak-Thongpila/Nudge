import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/task.dart';
import '../models/recommendation.dart';
import '../models/dashboard_data.dart';
import '../models/focus_session.dart';
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

  /// Deliberately postpones a task (Explicit Postpone - Ticket 04)
  Future<Task> postponeTask(int taskId) async {
    final headers = await _getHeaders();
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/tasks/$taskId/postpone'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Task.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      throw Exception(
        'Failed to postpone task: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Fetches top recommended task for starting right now
  Future<Recommendation?> getRecommendedTask() async {
    final headers = await _getHeaders();
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/tasks/recommended'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final recJson = data['data'] as Map<String, dynamic>?;
      if (recJson == null) return null;
      return Recommendation.fromJson(recJson);
    } else {
      throw Exception(
        'Failed to fetch recommendation: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Fetches structured dashboard grouped into recommended, next, later, and summary
  Future<DashboardData> getDashboard() async {
    final headers = await _getHeaders();
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DashboardData.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      throw Exception(
        'Failed to fetch dashboard: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Starts a focus session on a task and auto-transitions status to IN_PROGRESS
  Future<Task> startFocusSession(int taskId) async {
    final headers = await _getHeaders();
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/tasks/$taskId/start'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final innerData = data['data'] as Map<String, dynamic>;
      return Task.fromJson(innerData['task'] as Map<String, dynamic>);
    } else {
      throw Exception(
        'Failed to start focus session: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Records a completed or interrupted focus session
  Future<FocusSession> recordFocusSession({
    required int taskId,
    required int durationMinutes,
    required bool completed,
  }) async {
    final headers = await _getHeaders();
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/focus/sessions'),
      headers: headers,
      body: jsonEncode({
        'taskId': taskId,
        'durationMinutes': durationMinutes,
        'completed': completed,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return FocusSession.fromJson(data['data'] as Map<String, dynamic>);
    } else {
      throw Exception(
        'Failed to record focus session: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Fetches focus sessions history for a task
  Future<List<FocusSession>> getFocusSessions(int taskId) async {
    final headers = await _getHeaders();
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/focus/sessions?taskId=$taskId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>;
      return list
          .map((item) => FocusSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
        'Failed to fetch focus sessions: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
