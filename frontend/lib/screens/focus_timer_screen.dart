import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_client.dart';

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
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'พักก่อนไหม?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'ไม่เป็นไรเลยหากคุณยังไม่พร้อม การเริ่มลงมือทำก้าวแรกถือว่ายอดเยี่ยมแล้ว',
          style: TextStyle(color: Color(0xFF94A3B8), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ทำต่ออีกนิด', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
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
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFF10B981), width: 2),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF10B981),
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'ครบ 10 นาทีแล้ว! 🎉',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'คุณก้าวผ่านแรงต้านก้าวแรกได้สำเร็จแล้ว\nตอนนี้อยากทำอะไรต่อ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // Option 1: Continue for another 10 min
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text(
                    'ทำต่ออีก 10 นาที (กำลังติดลม)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text(
                    'เสร็จงานนี้แล้ว',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                    foregroundColor: const Color(0xFF94A3B8),
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: _handleGiveUp,
        ),
        title: const Text(
          'Focus Session (10 นาที)',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Task details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ความสำคัญ: ${widget.task.importance}/5',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (widget.task.isPotentiallyAvoided)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '⚠️ ถูกเลื่อนบ่อย',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Circular Countdown Timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      backgroundColor: const Color(0xFF1E293B),
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
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRunning ? 'กำลังโฟกัส...' : 'หยุดชั่วคราว',
                        style: TextStyle(
                          color: _isRunning ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Gentle supportive quote
              const Text(
                '“แค่เริ่มต้นทำ 10 นาที สมองจะเริ่มคลายความกังวล”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
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
                      backgroundColor: const Color(0xFF1E293B),
                      padding: const EdgeInsets.all(16),
                    ),
                    icon: const Icon(Icons.stop_rounded, color: Color(0xFFEF4444), size: 28),
                    tooltip: 'หยุดพักก่อน',
                    onPressed: _handleGiveUp,
                  ),
                  const SizedBox(width: 24),
                  // Pause / Play toggle
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    );
  }
}
