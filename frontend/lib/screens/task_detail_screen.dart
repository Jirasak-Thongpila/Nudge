import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/focus_session.dart';
import '../services/api_client.dart';
import 'focus_timer_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final ApiClient apiClient;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.apiClient,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _task;
  List<FocusSession> _focusSessions = [];
  bool _isLoadingSessions = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _fetchDetailsAndSessions();
  }

  Future<void> _fetchDetailsAndSessions() async {
    try {
      final updatedTask = await widget.apiClient.getTask(_task.id);
      final sessions = await widget.apiClient.getFocusSessions(_task.id);
      if (mounted) {
        setState(() {
          _task = updatedTask;
          _focusSessions = sessions;
          _isLoadingSessions = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSessions = false);
      }
    }
  }

  Future<void> _startFocusSession() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FocusTimerScreen(
          task: _task,
          apiClient: widget.apiClient,
        ),
      ),
    );

    _fetchDetailsAndSessions();
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 บันทึกงานสำเร็จเรียบร้อยแล้ว!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _confirmAndPostpone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'เลื่อนงานนี้ไปก่อน?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'คุณกำลังเลือกที่จะเลื่อนงานนี้อย่างตั้งใจ (Explicit Postpone)\n\nระบบจะบันทึกข้อมูลเพื่อช่วยแนะนำขั้นตอนที่เล็กลงในภายหลัง โดยไม่ตัดสินคุณ',
          style: TextStyle(color: Color(0xFF94A3B8), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            child: const Text('เลื่อนไปก่อน'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final updated = await widget.apiClient.postponeTask(_task.id);
      setState(() {
        _task = updated;
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกการเลื่อนงานแล้ว (เลื่อนไปแล้ว ${updated.postponeCount} ครั้ง)'),
            backgroundColor: Colors.indigo.shade800,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเลื่อนงานได้: $e')),
        );
      }
    }
  }

  Future<void> _toggleCompletion() async {
    final newStatus = _task.isCompleted ? 'NOT_STARTED' : 'COMPLETED';
    setState(() => _isProcessing = true);
    try {
      final updated = await widget.apiClient.updateTaskStatus(_task.id, newStatus);
      setState(() {
        _task = updated;
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updated.isCompleted ? '🎉 ทำงานนี้สำเร็จแล้ว!' : 'เปลี่ยนสถานะเป็นยังไม่เสร็จ'),
            backgroundColor: updated.isCompleted ? const Color(0xFF10B981) : Colors.indigo,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเปลี่ยนสถานะได้: $e')),
        );
      }
    }
  }

  Future<void> _sendLineActionNudge() async {
    setState(() => _isProcessing = true);
    try {
      await widget.apiClient.sendLineActionNudge(_task.id);
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💬 ส่ง Action Nudge เข้า LINE สำเร็จแล้ว! (พร้อม Deep Link เปิด Focus Session)'),
            backgroundColor: Color(0xFF06C755),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      final errorStr = e.toString();
      if (errorStr.contains('User has not linked a LINE account')) {
        _promptLinkLineAccount();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาดในการส่ง LINE Nudge: $e')),
          );
        }
      }
    }
  }

  Future<void> _promptLinkLineAccount() async {
    final lineIdController = TextEditingController();
    final shouldLink = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF06C755)),
            SizedBox(width: 8),
            Text('เชื่อมต่อ LINE OA', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'คุณยังไม่ได้เชื่อมต่อบัญชี LINE กับอุปกรณ์นี้\nกรุณาระบุ LINE User ID เพื่อรับ Action Nudge พร้อม Deep Link',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lineIdController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'LINE User ID (เช่น U12345...)',
                labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF475569))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF06C755))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF06C755)),
            child: const Text(
              'เชื่อมต่อและส่ง Nudge',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldLink == true && lineIdController.text.trim().isNotEmpty) {
      setState(() => _isProcessing = true);
      try {
        await widget.apiClient.linkLineAccount(lineIdController.text.trim());
        await widget.apiClient.sendLineActionNudge(_task.id);
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('💬 เชื่อมต่อ LINE และส่ง Action Nudge สำเร็จแล้ว!'),
              backgroundColor: Color(0xFF06C755),
            ),
          );
        }
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่สามารถเชื่อมต่อ LINE ได้: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog() async {
    final titleController = TextEditingController(text: _task.title);
    DateTime selectedDeadline = _task.deadline;
    int selectedImportance = _task.importance;
    int estimatedMinutes = _task.estimatedMinutes;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('แก้ไข Task', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'ชื่องาน',
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF475569)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF38BDF8)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ความสำคัญ (1-5):',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (i) {
                    final value = i + 1;
                    final isSelected = selectedImportance == value;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedImportance = value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$value',
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF38BDF8)),
                  title: const Text('กำหนดส่ง (Deadline)', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: Text(
                    _formatDateTime(selectedDeadline),
                    style: const TextStyle(color: Color(0xFF94A3B8)),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDeadline,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDeadline),
                      );
                      if (time != null) {
                        setModalState(() {
                          selectedDeadline = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text('เวลาที่คาดว่าจะใช้ (นาที):', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [15, 30, 45, 60, 90].map((mins) {
                    final isSelected = estimatedMinutes == mins;
                    return ChoiceChip(
                      label: Text('$mins นาที'),
                      selected: isSelected,
                      selectedColor: const Color(0xFF38BDF8),
                      backgroundColor: const Color(0xFF334155),
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setModalState(() => estimatedMinutes = mins);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
              child: const Text('บันทึก', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      setState(() => _isProcessing = true);
      try {
        final result = await widget.apiClient.updateTask(
          _task.id,
          title: titleController.text.trim(),
          deadline: selectedDeadline,
          importance: selectedImportance,
          estimatedMinutes: estimatedMinutes,
        );
        setState(() {
          _task = result;
          _isProcessing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('อัปเดตข้อมูลงานสำเร็จ'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('ลบ Task นี้?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'การลบจะเป็นแบบ Soft Delete (ADR-0004)\n\nระบบจะซ่อนงานนี้จากรายการหลัก แต่จะยังคงเก็บประวัติ Focus Session เพื่อไม่ให้สถิติของคุณสูญหาย',
          style: TextStyle(color: Color(0xFF94A3B8), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('ลบงานนี้'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await widget.apiClient.deleteTask(_task.id);
        if (mounted) {
          Navigator.of(context).pop(true); // Return to previous screen with deleted flag
        }
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่สามารถลบงานได้: $e')),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = _task.isOverdue || _task.isDueToday;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text(
          'รายละเอียด Task',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
            tooltip: 'แก้ไข',
            onPressed: _isProcessing ? null : _showEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            tooltip: 'ลบงาน',
            onPressed: _isProcessing ? null : _confirmAndDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & Urgency banner
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _task.isCompleted
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _task.isCompleted
                                ? '✓ เสร็จสิ้นแล้ว'
                                : (_task.status == 'IN_PROGRESS' ? '⏳ กำลังดำเนินการ' : '⚪ ยังไม่เริ่ม'),
                            style: TextStyle(
                              color: _task.isCompleted ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                : const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _task.daysRemainingText,
                            style: TextStyle(
                              color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF818CF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Task Title
                    Text(
                      _task.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),

                    if (_task.adaptiveNudgeMessage != null && !_task.isCompleted) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF818CF8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.psychology_alt_rounded, color: Color(0xFF818CF8), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _task.adaptiveNudgeMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFC7D2FE),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_task.isPotentiallyAvoided) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade700),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'งานนี้ถูกเลื่อนหลายครั้งและใกล้กำหนดส่ง ลองเริ่มด้วยช่วงสั้นๆ 10 นาที เพื่อคลายแรงต้าน',
                                style: TextStyle(color: Colors.amber, fontSize: 13, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'กำหนดส่ง',
                            value: _formatDateTime(_task.deadline),
                          ),
                          const Divider(color: Color(0xFF334155), height: 24),
                          _buildDetailRow(
                            icon: Icons.star_rounded,
                            label: 'ระดับความสำคัญ',
                            value: '${_task.importance}/5',
                          ),
                          const Divider(color: Color(0xFF334155), height: 24),
                          _buildDetailRow(
                            icon: Icons.timer_outlined,
                            label: 'เวลาที่คาดว่าจะใช้',
                            value: '${_task.estimatedMinutes} นาที',
                          ),
                          const Divider(color: Color(0xFF334155), height: 24),
                          _buildDetailRow(
                            icon: Icons.schedule_rounded,
                            label: 'จำนวนครั้งที่เลื่อน',
                            value: '${_task.postponeCount} ครั้ง',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF94A3B8),
                              side: const BorderSide(color: Color(0xFF475569)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: const Text('เลื่อนไปก่อน'),
                            onPressed: _confirmAndPostpone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _task.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                              side: BorderSide(
                                color: _task.isCompleted ? const Color(0xFF475569) : const Color(0xFF10B981),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: Icon(
                              _task.isCompleted ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            label: Text(_task.isCompleted ? 'ยกเลิกเสร็จ' : 'เสร็จงานนี้'),
                            onPressed: _toggleCompletion,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Focus Session CTA
                    if (!_task.isCompleted) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: const Text(
                            'เริ่ม Focus Session 10 นาที',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _startFocusSession,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF06C755),
                            side: const BorderSide(color: Color(0xFF06C755)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: const Text(
                            'ส่ง Action Nudge เข้า LINE OA',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          onPressed: _sendLineActionNudge,
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Focus Sessions History
                    const Text(
                      'ประวัติการโฟกัส (Focus Sessions)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_isLoadingSessions)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                        ),
                      )
                    else if (_focusSessions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.history_toggle_off_rounded, color: Color(0xFF64748B), size: 36),
                            SizedBox(height: 8),
                            Text(
                              'ยังไม่มีประวัติการโฟกัสสำหรับงานนี้',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _focusSessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final session = _focusSessions[i];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  session.completed
                                      ? Icons.check_circle_rounded
                                      : Icons.pause_circle_outline_rounded,
                                  color: session.completed ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'โฟกัส ${session.durationMinutes} นาที ${session.completed ? '(สำเร็จ)' : '(หยุดก่อน)'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDateTime(session.startedAt),
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF38BDF8), size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
