import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class FocusTimerScreen extends StatefulWidget {
  final Task task;
  final ApiClient? apiClient;
  final int totalSeconds;

  const FocusTimerScreen({
    super.key,
    required this.task,
    this.apiClient,
    this.totalSeconds = 600, // 10 minutes (ADR-0003)
  });

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  late final ApiClient _apiClient;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _remainingSeconds = widget.totalSeconds;
    _initSession();
    _startTimer();
  }

  Future<void> _initSession() async {
    try {
      await _apiClient.startFocusSession(widget.task.id);
    } catch (_) {
      // Non-blocking: timer can continue client-side even if network hiccup
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          _elapsedSeconds++;
        });
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _toggleTimer() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  Future<void> _onTimerComplete() async {
    try {
      final minutes = (widget.totalSeconds / 60).round();
      await _apiClient.recordFocusSession(
        taskId: widget.task.id,
        durationMinutes: minutes > 0 ? minutes : 1,
        completed: true,
      );
    } catch (_) {
      // Ignored non-critical
    } finally {
      if (mounted) {
        _showCompletionSheet();
      }
    }
  }

  Future<void> _handleGiveUp() async {
    _pauseTimer();
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.cardRadius)),
        title: const Row(
          children: [
            Icon(Icons.self_improvement_rounded, color: AppColors.mindfulTeal),
            SizedBox(width: 8),
            Text(
              'พักก่อนไหม?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'ไม่เป็นไรเลยหากคุณยังไม่พร้อม การเริ่มลงมือทำก้าวแรกถือว่ายอดเยี่ยมแล้ว',
          style: TextStyle(color: AppColors.slate400, height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ทำต่ออีกนิด', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.slate700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonRadius)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('หยุดพักก่อน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      // Record interrupted session if elapsed >= 1 minute
      final elapsedMinutes = (_elapsedSeconds / 60).floor();
      if (elapsedMinutes > 0) {
        try {
          await _apiClient.recordFocusSession(
            taskId: widget.task.id,
            durationMinutes: elapsedMinutes,
            completed: false,
          );
        } catch (_) {}
      }
      if (mounted) Navigator.of(context).pop();
    } else {
      _startTimer();
    }
  }

  void _showCompletionSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.slate900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.completedEmerald.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.completedEmerald, width: 2),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: AppColors.completedEmerald,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'ครบ 10 นาทีแล้ว! 🎉',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'คุณก้าวผ่านแรงต้านก้าวแรกได้สำเร็จแล้ว\nตอนนี้อยากทำอะไรต่อ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.slate400,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // Option 1: Continue for another 10 min
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: AppColors.slate950,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                    ),
                  ),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text(
                    'ทำต่ออีก 10 นาที (กำลังติดลม)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _remainingSeconds = widget.totalSeconds;
                      _elapsedSeconds = 0;
                    });
                    _startTimer();
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Option 2: Mark completed
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.completedEmerald,
                    side: const BorderSide(color: AppColors.completedEmerald, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                    ),
                  ),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text(
                    'เสร็จงานนี้แล้ว',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await _apiClient.updateTaskStatus(widget.task.id, 'COMPLETED');
                    } catch (_) {}
                    if (mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Option 3: Short break
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.slate400,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('พักเบรกสั้นๆ แล้วกลับมาใหม่'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalSeconds > 0
        ? (_remainingSeconds / widget.totalSeconds)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.slate400),
          onPressed: _handleGiveUp,
        ),
        title: const Text(
          'Focus Session (10 นาที)',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryIndigo.withValues(alpha: 0.25),
                      AppColors.mindfulTeal.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Task details card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(AppRadius.cardRadius),
                      border: Border.all(color: AppColors.slate700),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppRadius.chipRadius),
                              ),
                              child: Text(
                                'ความสำคัญ: ${widget.task.importance}/5',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (widget.task.isPotentiallyAvoided)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.avoidedAmber.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(AppRadius.chipRadius),
                                  border: Border.all(color: AppColors.avoidedAmber.withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.amber300),
                                    SizedBox(width: 4),
                                    Text(
                                      'ถูกเลื่อนบ่อย',
                                      style: TextStyle(
                                        color: AppColors.amber300,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.task.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Circular Countdown Timer with Glow Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Subtle ambient glow ring around timer
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: _isRunning
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                                    blurRadius: 36,
                                    spreadRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        height: 240,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: AppColors.slate800,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF38BDF8),
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(_remainingSeconds),
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRunning ? const Color(0xFF38BDF8) : AppColors.amber300,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isRunning ? 'กำลังโฟกัส...' : 'หยุดชั่วคราว',
                                style: TextStyle(
                                  color: _isRunning ? const Color(0xFF38BDF8) : AppColors.slate400,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Gentle supportive quote
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.slate800.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.slate700.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.format_quote_rounded, color: AppColors.mindfulTeal, size: 20),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '“แค่เริ่มต้นทำ 10 นาที สมองจะเริ่มคลายความกังวล”',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.slate300,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Cancel button
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.slate800,
                          padding: const EdgeInsets.all(16),
                        ),
                        icon: const Icon(Icons.stop_rounded, color: AppColors.urgentRose, size: 28),
                        tooltip: 'หยุดพักก่อน',
                        onPressed: _handleGiveUp,
                      ),
                      const SizedBox(width: 20),
                      // Pause / Play toggle
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: AppColors.slate950,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.cardRadius),
                          ),
                        ),
                        onPressed: _toggleTimer,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              _isRunning ? 'หยุดชั่วคราว' : 'ทำต่อ',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
