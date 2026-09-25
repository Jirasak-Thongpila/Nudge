import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/liff_service.dart';
import '../services/notification_service.dart';
import 'add_task_screen.dart';
import 'task_list_screen.dart';
import 'focus_timer_screen.dart';
import 'task_detail_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ApiClient apiClient;
  final User user;

  const DashboardScreen({
    super.key,
    required this.apiClient,
    required this.user,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _dashboardData;
  Map<String, dynamic>? _nudgePreview;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.apiClient.getDashboard();
      Map<String, dynamic>? nudge;
      try {
        nudge = await widget.apiClient.getNudgePreview();
      } catch (_) {}

      setState(() {
        _dashboardData = data;
        _nudgePreview = nudge;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _onStartFocusSession(Task task) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FocusTimerScreen(
          task: task,
          apiClient: widget.apiClient,
        ),
      ),
    );
    // Reload dashboard after returning from focus session
    _fetchDashboard();
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 บันทึกงานสำเร็จเรียบร้อยแล้ว!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _openTaskDetail(Task task) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          apiClient: widget.apiClient,
        ),
      ),
    );
    if (result == true) {
      _fetchDashboard();
    }
  }

  Widget _buildSummaryStats(DashboardData data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('งานที่ต้องทำ', '${data.totalActive}', Colors.indigo),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          _buildStatItem(
            'อาจกำลังเลี่ยง',
            '${data.potentiallyAvoidedCount}',
            data.potentiallyAvoidedCount > 0 ? Colors.orange.shade800 : Colors.grey,
          ),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          _buildStatItem('เสร็จแล้ว', '${data.completedCount}', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildRecommendationHero(DashboardData data) {
    final rec = data.recommended;
    if (rec == null) {
      final hasCompleted = data.completedCount > 0;
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: hasCompleted ? const Color(0xFFF0FDF4) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                ),
                child: Icon(
                  hasCompleted ? Icons.celebration_rounded : Icons.spa_outlined,
                  size: 36,
                  color: hasCompleted ? const Color(0xFF16A34A) : const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasCompleted ? 'ยอดเยี่ยมมาก! วันนี้ไม่มีงานค้างแล้ว 🎉' : 'เริ่มต้นอย่างสบายใจ ไม่มีแรงกดดัน 🌱',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hasCompleted
                    ? 'คุณได้จัดการงานที่สำคัญเรียบร้อย พักผ่อนได้อย่างสบายใจ โดยไม่ต้องกังวล'
                    : 'Nudge พร้อมช่วยคุณเริ่มจัดการงานทีละนิด เริ่มสร้าง Task แรกของคุณได้เลย',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(hasCompleted ? 'เพิ่ม Task ใหม่' : 'สร้าง Task แรก'),
                onPressed: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTaskScreen(apiClient: widget.apiClient),
                    ),
                  );
                  if (created == true) {
                    _fetchDashboard();
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    final task = rec.task;
    final isUrgent = task.daysRemaining <= 1;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: task.isPotentiallyAvoided ? Colors.amber.shade300 : Colors.indigo.shade100,
          width: 1.5,
        ),
      ),
      color: task.isPotentiallyAvoided ? const Color(0xFFFFFDF5) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent ? Colors.red.shade50 : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: isUrgent ? Colors.red.shade700 : Colors.indigo,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUrgent ? '🔴 ควรเริ่มวันนี้' : '⚡ แนะนำให้เริ่มตอนนี้',
                        style: TextStyle(
                          color: isUrgent ? Colors.red.shade800 : Colors.indigo.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Priority: ${task.priorityScore}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20, color: Color(0xFF6366F1)),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'ดูรายละเอียด',
                  onPressed: () => _openTaskDetail(task),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openTaskDetail(task),
              child: Text(
                task.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChip(
                  task.daysRemaining < 0
                      ? 'เกินกำหนด ${-task.daysRemaining} วัน'
                      : task.daysRemaining == 0
                          ? 'ครบกำหนดวันนี้'
                          : 'เหลืออีก ${task.daysRemaining} วัน',
                  task.daysRemaining <= 1 ? Colors.red.shade700 : Colors.indigo.shade700,
                  task.daysRemaining <= 1 ? Colors.red.shade50 : Colors.indigo.shade50,
                ),
                _buildChip(
                  'สำคัญ: ${task.importance}/5',
                  Colors.amber.shade900,
                  Colors.amber.shade50,
                ),
                if (task.postponeCount > 0)
                  _buildChip(
                    'ถูกเลื่อน ${task.postponeCount} ครั้ง',
                    Colors.grey.shade800,
                    Colors.grey.shade100,
                  ),
              ],
            ),
            if (task.isPotentiallyAvoided) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '⚠️ อาจกำลังถูกเลื่อนซ้ำ (Potentially Avoided)',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF7C3AED), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec.adaptiveNudgeMessage,
                      style: const TextStyle(
                        color: Color(0xFF5B21B6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              rec.recommendationReason,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _onStartFocusSession(task),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.timer),
                label: const Text(
                  'เริ่ม 10 นาที',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTaskListSection(String title, List<Task> tasks, {required IconData icon}) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...tasks.map(
          (t) => Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              onTap: () => _openTaskDetail(t),
              title: Text(
                t.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                t.daysRemaining < 0
                    ? 'เกินกำหนด ${-t.daysRemaining} วัน'
                    : t.daysRemaining == 0
                        ? 'ครบกำหนดวันนี้'
                        : 'เหลืออีก ${t.daysRemaining} วัน • สำคัญ: ${t.importance}/5',
                style: TextStyle(
                  color: t.daysRemaining <= 1 ? Colors.red.shade700 : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
              trailing: TextButton(
                onPressed: () => _onStartFocusSession(t),
                child: const Text('เริ่ม 10 นาที'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: Text(
          widget.user.lineUserId != null
              ? 'ต้องการออกจากระบบ LINE (${widget.user.lineUserId}) หรือไม่?'
              : 'ต้องการออกจากระบบหรือไม่? (ข้อมูล Guest จะยังคงอยู่ในเครื่องนี้)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      LiffService.instance.logout();
      widget.apiClient.setLineUserId(null);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(apiClient: widget.apiClient),
        ),
        (route) => false,
      );
    }
  }

  void _showNotificationCenter() {
    final decision = _nudgePreview?['decision'] as Map<String, dynamic>?;
    final hasPerm = PlatformNotification.hasPermission();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_active, color: Color(0xFF6366F1)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ศูนย์แจ้งเตือนอัจฉริยะ (Smart Nudge)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'แจ้งเตือนคู่ขนานผ่าน LINE OA และระบบอุปกรณ์',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Active Action Nudge if any
                    if (decision != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '🌱 คำแนะนำเริ่มก้าวแรกวันนี้',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    decision['reason'] ?? 'ACTION',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              decision['title'] ?? 'งานสำคัญ',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              decision['reasonText'] ?? '',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '“${decision['nudgeMessage'] ?? 'ลองเริ่ม 10 นาทีไหม?'}”',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4338CA),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                label: const Text('เริ่ม 10 นาทีเลย'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  final taskId = decision['taskId'] as int?;
                                  if (taskId != null) {
                                    final allTasks = [
                                      if (_dashboardData?.recommended != null)
                                        _dashboardData!.recommended!.task,
                                      ...?_dashboardData?.next,
                                      ...?_dashboardData?.later,
                                    ];
                                    final found = allTasks.cast<Task?>().firstWhere(
                                          (t) => t?.id == taskId,
                                          orElse: () => _dashboardData?.recommended?.task,
                                        );
                                    if (found != null) {
                                      _onStartFocusSession(found);
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Smart Cadence Explanation Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🗓️ รูปแบบการแจ้งเตือน (Smart Cadence)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '• งานสำคัญระยะยาว: ระบบจะเตือนวันละ 1 ครั้ง ในช่วงเวลา 08:00 - 21:00 น.\n'
                            '• งานใกล้กำหนดส่ง: จะเตือนล่วงหน้า 1-2 วัน และเตือนก่อนถึงกำหนด\n'
                            '• งานที่ถูกเลื่อน: จะแนะนำก้าวเริ่มต้น 10 นาที เพื่อลดแรงต้าน',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Browser Notification Permission / Test
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              hasPerm ? Icons.notifications_active : Icons.notifications_none,
                              size: 18,
                            ),
                            label: Text(
                              hasPerm ? 'เปิดแจ้งเตือนแล้ว' : 'ขอสิทธิ์แจ้งเตือน',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
                              final granted = await PlatformNotification.requestPermission();
                              setModalState(() {});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      granted
                                          ? '✅ อนุญาตการแจ้งเตือนสำเร็จแล้ว'
                                          : '⚠️ ยังไม่ได้รับสิทธิ์การแจ้งเตือน',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('ทดสอบแจ้งเตือน', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              PlatformNotification.showNotification(
                                '🌱 Nudge: เริ่มก้าวแรก 10 นาทีกันนะ',
                                body: 'ระบบแจ้งเตือนของ Nudge พร้อมทำงานแล้วครับ',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🔔 ส่งการแจ้งเตือนทดสอบแล้ว'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nudge'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                if (_nudgePreview?['decision'] != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'ศูนย์แจ้งเตือน Nudge',
            onPressed: _showNotificationCenter,
          ),
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: 'ดู Task ทั้งหมด',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskListScreen(
                    apiClient: widget.apiClient,
                    user: widget.user,
                  ),
                ),
              );
              _fetchDashboard();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: _fetchDashboard,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'บัญชีผู้ใช้',
            onSelected: (value) {
              if (value == 'logout') {
                _confirmLogout();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.user.lineUserId != null
                          ? 'LINE Connected'
                          : 'Guest User',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user.lineUserId ?? 'ID #${widget.user.id}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _fetchDashboard,
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDashboard,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryStats(_dashboardData!),
                        const SizedBox(height: 16),
                        _buildRecommendationHero(_dashboardData!),
                        const SizedBox(height: 24),
                        _buildTaskListSection(
                          'งานถัดไป (Next)',
                          _dashboardData!.next,
                          icon: Icons.arrow_forward_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildTaskListSection(
                          'งานที่ยังไม่เร่งด่วน (Later)',
                          _dashboardData!.later,
                          icon: Icons.access_time_rounded,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddTaskScreen(apiClient: widget.apiClient),
            ),
          );
          if (created == true) {
            _fetchDashboard();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('เพิ่ม Task'),
      ),
    );
  }
}
