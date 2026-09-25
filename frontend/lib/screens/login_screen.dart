import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/deep_link_service.dart';
import '../services/liff_service.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_toggle_button.dart';
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



  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _initialize();
  }

  @override
  void dispose() {
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
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: 12,
              right: 16,
              child: ThemeToggleButton(),
            ),
            Center(
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
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: colors.cardBorder),
        boxShadow: colors.cardShadow,
      ),
      padding: const EdgeInsets.all(36.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _loadingMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ระบบกำลังเตรียมความพร้อมของข้อมูล',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineState() {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
        boxShadow: colors.cardShadow,
      ),
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.rose.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.roseLight),
          ),
          const SizedBox(height: 20),
          Text(
            'ไม่สามารถเชื่อมต่อ Backend ได้',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ??
                'กรุณาตรวจสอบว่าเซิร์ฟเวอร์ Backend รันอยู่ที่ ${_apiClient.baseUrl}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _initialize,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonRadius)),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('ลองใหม่อีกครั้ง'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    final colors = context.colors;

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
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.primaryGlow,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Nudge',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ก้าวข้ามการผัดวันประกันพรุ่งด้วยก้าวเล็กๆ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: AppRadius.pillRadius,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Action Nudge • Deadline Awareness',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.isDark ? AppColors.primaryLight : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Main Login Action Card
        Container(
          decoration: BoxDecoration(
            color: colors.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: colors.cardBorder),
            boxShadow: colors.cardShadow,
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Primary Action: LINE Login
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                  boxShadow: AppShadows.lineGlow,
                ),
                child: FilledButton.icon(
                  onPressed: _handleLineLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lineGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
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
              ),
              const SizedBox(height: 10),
              Text(
                'เชื่อมต่อบัญชีเพื่อรับการแจ้งเตือน Action Nudge ผ่าน LINE OA',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: colors.cardBorder)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      'หรือ',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ),
                  Expanded(child: Divider(color: colors.cardBorder)),
                ],
              ),
              const SizedBox(height: 20),

              // Secondary Action: Guest Mode
              OutlinedButton.icon(
                onPressed: _handleGuestLogin,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  backgroundColor: colors.cardSurfaceElevated,
                  side: BorderSide(color: colors.cardBorderGlow),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
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
              const SizedBox(height: 8),
              Text(
                'สร้างและจัดการงานได้ทันที ข้อมูลจะผูกกับอุปกรณ์นี้ (ADR-0001)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
        ),



        const SizedBox(height: 24),
        Center(
          child: Text(
            'Nudge: Behavioral Productivity System',
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}
