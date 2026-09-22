import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/deep_link_service.dart';
import '../services/liff_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const LoginScreen({super.key, this.apiClient});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final ApiClient _apiClient;
  bool _isLoading = true;
  String _loadingMessage = 'กำลังตรวจสอบการเชื่อมต่อ...';
  bool _backendOffline = false;
  String? _errorMessage;

  final TextEditingController _devLineIdController =
      TextEditingController(text: 'test_line_user_01');

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _initialize();
  }

  @override
  void dispose() {
    _devLineIdController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _backendOffline = false;
      _errorMessage = null;
      _loadingMessage = 'กำลังตรวจสอบการเชื่อมต่อ...';
    });

    try {
      final healthy = await _apiClient.checkHealth();
      if (!healthy) {
        setState(() {
          _backendOffline = true;
          _isLoading = false;
        });
        return;
      }

      // Check LIFF on Web
      if (kIsWeb) {
        setState(() {
          _loadingMessage = 'กำลังเชื่อมต่อ LINE LIFF SDK...';
        });

        final liffSupported = await LiffService.instance.init();
        if (liffSupported && LiffService.instance.lineUserId != null) {
          final profile = LiffService.instance.profile;
          setState(() {
            _loadingMessage = 'กำลังเข้าสู่ระบบด้วย LINE...';
          });

          final user = await _apiClient.loginWithLine(
            LiffService.instance.lineUserId!,
            displayName: profile?.displayName,
            pictureUrl: profile?.pictureUrl,
          );

          if (mounted) {
            _navigateToDashboard(user);
            return;
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'เกิดข้อผิดพลาดในการเริ่มต้นระบบ: $e';
      });
    }
  }

  Future<void> _handleLineLogin() async {
    if (kIsWeb && LiffService.instance.isLiffSupported) {
      LiffService.instance.login();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'LINE LIFF ต้องเปิดใช้งานผ่าน LINE In-App Browser หรือโดเมนที่ลงทะเบียนไว้ หากกำลังทดสอบในเครื่อง Local กรุณาใช้ "โหมดนักพัฒนา" ด้านล่าง',
          ),
          backgroundColor: Colors.indigo.shade800,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'เข้าใจแล้ว',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'กำลังเข้าใช้งานแบบ Guest...';
    });

    try {
      final user = await _apiClient.getCurrentUser();
      if (mounted) {
        _navigateToDashboard(user);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เข้าใช้งานแบบ Guest ไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDevLogin(String lineUserId, {String? displayName}) async {
    if (lineUserId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุ LINE User ID สำหรับทดสอบ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'กำลังจำลองการเข้าสู่ระบบ LINE ($lineUserId)...';
    });

    try {
      final user = await _apiClient.loginWithLine(
        lineUserId.trim(),
        displayName: displayName ?? 'Dev Tester',
      );
      if (mounted) {
        _navigateToDashboard(user);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('จำลองการเข้าสู่ระบบล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToDashboard(User user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          apiClient: _apiClient,
          user: user,
        ),
      ),
    );

    // Deep link check (Ticket 09 / LINE Flex start action)
    if (kIsWeb) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50 background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _isLoading
                  ? _buildLoadingState()
                  : _backendOffline
                      ? _buildOfflineState()
                      : _buildLoginCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(36.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _loadingMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ระบบกำลังเตรียมความพร้อมของข้อมูล',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.red.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              'ไม่สามารถเชื่อมต่อ Backend ได้',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'กรุณาตรวจสอบว่าเซิร์ฟเวอร์ Backend รันอยู่ที่ ${_apiClient.baseUrl}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _initialize,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่อีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero Section
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          alignment: Alignment.center,
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nudge',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Color(0xFF1E293B), // Slate 800
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ก้าวข้ามการผัดวันประกันพรุ่งด้วยก้าวเล็กๆ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF), // Indigo 50
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Action Nudge • Deadline Awareness',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5), // Indigo 600
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Main Login Action Card
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Primary Action: LINE Login
                FilledButton.icon(
                  onPressed: _handleLineLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF06C755), // LINE Official Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 22),
                  label: const Text(
                    'เข้าสู่ระบบด้วย LINE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'เชื่อมต่อบัญชีเพื่อรับการแจ้งเตือน Action Nudge ผ่าน LINE OA',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'หรือ',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade200)),
                  ],
                ),
                const SizedBox(height: 20),

                // Secondary Action: Guest Mode
                OutlinedButton.icon(
                  onPressed: _handleGuestLogin,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.person_outline_rounded, size: 20),
                  label: const Text(
                    'ใช้งานแบบไม่ผูกบัญชี (Guest Mode)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'สร้างและจัดการงานได้ทันที ข้อมูลจะผูกกับอุปกรณ์นี้ (ADR-0001)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Developer / Testing Mode Panel
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(
                Icons.code_rounded,
                color: Colors.amber.shade800,
                size: 22,
              ),
              title: Text(
                'โหมดนักพัฒนา (Dev / Test Mode)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              subtitle: Text(
                'จำลอง LINE Login บน Localhost / Windows',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  'เลือกบัญชีทดสอบด่วน (1-Click Simulators):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleDevLogin(
                          'test_line_user_01',
                          displayName: 'Test User 01',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.person, size: 16),
                        label: const Text('User 01', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleDevLogin(
                          'test_line_user_02',
                          displayName: 'Test User 02',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.person, size: 16),
                        label: const Text('User 02', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _devLineIdController,
                        decoration: InputDecoration(
                          labelText: 'Custom LINE User ID',
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _handleDevLogin(
                        _devLineIdController.text,
                        displayName: 'Custom Dev User',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Center(
          child: Text(
            'Nudge: Behavioral Productivity System',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ),
      ],
    );
  }
}
