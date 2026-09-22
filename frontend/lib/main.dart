import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/api_client.dart';
import 'services/deep_link_service.dart';
import 'services/liff_service.dart';
import 'screens/task_list_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

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
      home: const LoginScreen(),
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

      User? user;
      if (kIsWeb) {
        final liffSupported = await LiffService.instance.init();
        if (liffSupported && LiffService.instance.lineUserId != null) {
          final profile = LiffService.instance.profile;
          user = await _apiClient.loginWithLine(
            LiffService.instance.lineUserId!,
            displayName: profile?.displayName,
            pictureUrl: profile?.pictureUrl,
          );
        }
      }

      user ??= await _apiClient.getCurrentUser();

      setState(() {
        _user = user;
        _isLoading = false;
      });

      if (kIsWeb && mounted) {
        final taskIdStr = Uri.base.queryParameters['taskId'];
        if (taskIdStr != null) {
          final taskId = int.tryParse(taskIdStr);
          if (taskId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                DeepLinkService.navigateFromDeepLink(
                  context: context,
                  apiClient: _apiClient,
                  uriString: 'nudge://focus?taskId=$taskId',
                );
              }
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
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
                                const Divider(height: 20),
                                _buildInfoRow(
                                  'LINE OA Link',
                                  _user?.lineUserId != null
                                      ? 'เชื่อมต่อแล้ว (${_user!.lineUserId})'
                                      : 'ยังไม่ได้เชื่อมต่อ',
                                  _user?.lineUserId != null
                                      ? const Color(0xFF06C755)
                                      : Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _user == null
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DashboardScreen(
                                        apiClient: _apiClient,
                                        user: _user!,
                                      ),
                                    ),
                                  );
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          icon: const Icon(Icons.dashboard_rounded),
                          label: const Text(
                            'เข้าสู่ Dashboard',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _connectToBackend,
                              icon: const Icon(Icons.refresh),
                              label: const Text('รีเฟรชสถานะ'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _user == null
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TaskListScreen(
                                            apiClient: _apiClient,
                                            user: _user!,
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.format_list_bulleted),
                              label: const Text('ดูรายการ Task'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _user == null ? null : _openDeepLinkTester,
                          icon: const Icon(Icons.link_rounded, color: Color(0xFF6366F1)),
                          label: const Text(
                            'ทดสอบ Deep Link (nudge://focus?taskId=...)',
                            style: TextStyle(color: Color(0xFF6366F1)),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Future<void> _openDeepLinkTester() async {
    final controller = TextEditingController(text: 'nudge://focus?taskId=1');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('จำลองการเปิด Deep Link จาก LINE'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เมื่อกดปุ่ม "เริ่ม 10 นาที" จาก LINE Flex Message ระบบจะเรียก URL ดังนี้:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Deep Link URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('เปิด Deep Link'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await DeepLinkService.navigateFromDeepLink(
        context: context,
        apiClient: _apiClient,
        uriString: controller.text.trim(),
      );
    }
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
