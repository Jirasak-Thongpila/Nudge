import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NudgeApp());
}

class NudgeApp extends StatelessWidget {
  const NudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nudge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo primary
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const WalkingSkeletonScreen(),
    );
  }
}

class WalkingSkeletonScreen extends StatefulWidget {
  const WalkingSkeletonScreen({super.key});

  @override
  State<WalkingSkeletonScreen> createState() => _WalkingSkeletonScreenState();
}

class _WalkingSkeletonScreenState extends State<WalkingSkeletonScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  bool _isBackendHealthy = false;
  User? _user;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _connectToBackend();
  }

  Future<void> _connectToBackend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final healthy = await _apiClient.checkHealth();
      if (!healthy) {
        throw Exception('Backend health check returned non-200 status');
      }

      final user = await _apiClient.getCurrentUser();
      setState(() {
        _isBackendHealthy = true;
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isBackendHealthy = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nudge — Walking Skeleton'),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Connecting to Nudge backend...'),
                  ],
                )
              : _errorMessage != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Connection Failed',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _connectToBackend,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Connection'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                        const SizedBox(height: 16),
                        const Text(
                          'Connected to Backend',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow('Status', 'Backend Online', Colors.green),
                                const Divider(height: 20),
                                _buildInfoRow('User ID', '#${_user?.id ?? "N/A"}', Colors.black87),
                                const Divider(height: 20),
                                _buildInfoRow('Device UUID', _user?.deviceUuid ?? "N/A", Colors.black54),
                                const Divider(height: 20),
                                _buildInfoRow(
                                  'Auth Type',
                                  'Anonymous UUID (ADR-0001)',
                                  Colors.indigo,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.tonalIcon(
                          onPressed: _connectToBackend,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Status'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
