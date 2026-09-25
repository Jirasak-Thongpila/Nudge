import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/liff_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
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
    return Row(
      children: [
        Expanded(
          child: _buildModernStatCard(
            label: 'งานที่ต้องทำ',
            value: '${data.totalActive}',
            icon: Icons.assignment_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildModernStatCard(
            label: 'อาจกำลังเลี่ยง',
            value: '${data.potentiallyAvoidedCount}',
            icon: Icons.history_toggle_off_rounded,
            color: data.potentiallyAvoidedCount > 0 ? AppColors.amber : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildModernStatCard(
            label: 'เสร็จสิ้นแล้ว',
            value: '${data.completedCount}',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.smRadius,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationHero(DashboardData data) {
    final rec = data.recommended;
    if (rec == null) {
      final hasCompleted = data.completedCount > 0;
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: AppRadius.xlRadius,
          border: Border.all(
            color: hasCompleted ? AppColors.teal.withValues(alpha: 0.4) : AppColors.cardBorderGlow,
          ),
          boxShadow: AppShadows.cardHover,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (hasCompleted ? AppColors.teal : AppColors.primary).withValues(alpha: 0.15),
                border: Border.all(
                  color: (hasCompleted ? AppColors.teal : AppColors.primary).withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: hasCompleted ? AppShadows.mintGlow : AppShadows.primaryGlow,
              ),
              child: Icon(
                hasCompleted ? Icons.celebration_rounded : Icons.spa_rounded,
                size: 38,
                color: hasCompleted ? AppColors.teal : AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasCompleted ? 'ยอดเยี่ยมมาก! วันนี้ไม่มีงานค้างแล้ว 🎉' : 'เริ่มต้นอย่างสบายใจ ไม่มีแรงกดดัน 🌱',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasCompleted
                  ? 'คุณได้จัดการงานที่สำคัญเรียบร้อย พักผ่อนได้อย่างสบายใจ โดยไม่ต้องกังวล'
                  : 'Nudge พร้อมช่วยคุณเริ่มจัดการงานทีละนิด เริ่มสร้าง Task แรกของคุณได้เลย',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13.5),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdRadius,
                boxShadow: AppShadows.primaryGlow,
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  hasCompleted ? 'เพิ่ม Task ใหม่' : 'สร้าง Task แรก',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
            ),
          ],
        ),
      );
    }

    final task = rec.task;
    final isUrgent = task.daysRemaining <= 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurfaceElevated,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: task.isPotentiallyAvoided
              ? AppColors.amber.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: AppShadows.cardHover,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xlRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Bar with Dark Gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: task.isPotentiallyAvoided
                      ? [const Color(0xFF241607), AppColors.cardSurfaceElevated]
                      : [const Color(0xFF1E1B4B), AppColors.cardSurfaceElevated],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? AppColors.rose
                          : (task.isPotentiallyAvoided ? AppColors.amber : AppColors.primary),
                      borderRadius: AppRadius.pillRadius,
                      boxShadow: isUrgent ? [
                        BoxShadow(
                          color: AppColors.rose.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ] : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUrgent ? 'ควรเริ่มวันนี้' : 'แนะนำให้เริ่มตอนนี้',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: AppRadius.pillRadius,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      'Priority: ${task.priorityScore}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primaryLight),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'ดูรายละเอียด',
                    onPressed: () => _openTaskDetail(task),
                  ),
                ],
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openTaskDetail(task),
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        task.daysRemaining <= 1 ? AppColors.roseLight : AppColors.primaryLight,
                        icon: Icons.calendar_today_rounded,
                      ),
                      _buildChip(
                        'ความสำคัญ ${task.importance}/5',
                        AppColors.amberLight,
                        icon: Icons.star_rounded,
                      ),
                      if (task.estimatedMinutes > 0)
                        _buildChip(
                          '${task.estimatedMinutes} นาที',
                          AppColors.textSecondary,
                          icon: Icons.schedule_rounded,
                        ),
                      if (task.postponeCount > 0)
                        _buildChip(
                          'เลื่อนแล้ว ${task.postponeCount} ครั้ง',
                          AppColors.textSecondary,
                          icon: Icons.refresh_rounded,
                        ),
                    ],
                  ),
                  if (task.isPotentiallyAvoided) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF231608),
                        borderRadius: AppRadius.mdRadius,
                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.support_agent_rounded, size: 18, color: AppColors.amberLight),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'กำลังถูกเลื่อนซ้ำ — ลองเริ่มแค่ 10 นาทีเพื่อคลายความกังวล',
                              style: TextStyle(
                                color: AppColors.amberLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14172B),
                      borderRadius: AppRadius.mdRadius,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.format_quote_rounded, color: AppColors.primaryLight, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rec.adaptiveNudgeMessage,
                            style: const TextStyle(
                              color: Color(0xFFE0E7FF),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rec.recommendationReason,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.mdRadius,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: AppShadows.primaryGlow,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _onStartFocusSession(task),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
                      ),
                      icon: const Icon(Icons.play_circle_filled_rounded, size: 22),
                      label: const Text(
                        'เริ่ม 10 นาที (Focus Session)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text, Color textColor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: textColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: AppRadius.smRadius,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, size: 16, color: AppColors.primaryLight),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cardSurfaceElevated,
                borderRadius: AppRadius.pillRadius,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                '${tasks.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tasks.map(
          (t) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: AppRadius.lgRadius,
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppShadows.card,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadius.lgRadius,
                onTap: () => _openTaskDetail(t),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.daysRemaining <= 1
                              ? AppColors.rose.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: t.daysRemaining <= 1
                                ? AppColors.rose.withValues(alpha: 0.3)
                                : AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          t.isCompleted
                              ? Icons.check_circle_rounded
                              : (t.daysRemaining <= 1 ? Icons.alarm_rounded : Icons.task_alt_rounded),
                          color: t.daysRemaining <= 1 ? AppColors.roseLight : AppColors.primaryLight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: t.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                                decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  t.daysRemaining < 0
                                      ? 'เกินกำหนด ${-t.daysRemaining} วัน'
                                      : t.daysRemaining == 0
                                          ? 'ครบกำหนดวันนี้'
                                          : 'เหลือ ${t.daysRemaining} วัน',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: t.daysRemaining <= 1 ? AppColors.roseLight : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: AppColors.cardBorderGlow,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '⭐ ${t.importance}/5',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primaryLight, size: 28),
                        tooltip: 'เริ่มโฟกัส 10 นาที',
                        onPressed: () => _onStartFocusSession(t),
                      ),
                    ],
                  ),
                ),
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
      backgroundColor: AppColors.cardSurfaceElevated,
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
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.notifications_active, color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ศูนย์แจ้งเตือนอัจฉริยะ (Smart Nudge)',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              Text(
                                'แจ้งเตือนคู่ขนานผ่าน LINE OA และระบบอุปกรณ์',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                          color: const Color(0xFF14172B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
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
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
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
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              decision['reasonText'] ?? '',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '“${decision['nudgeMessage'] ?? 'ลองเริ่ม 10 นาทีไหม?'}”',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC7D2FE),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                label: const Text('เริ่ม 10 นาทีเลย'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
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
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🗓️ รูปแบบการแจ้งเตือน (Smart Cadence)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '• งานสำคัญระยะยาว: ระบบจะเตือนวันละ 1 ครั้ง ในช่วงเวลา 08:00 - 21:00 น.\n'
                            '• งานใกล้กำหนดส่ง: จะเตือนล่วงหน้า 1-2 วัน และเตือนก่อนถึงกำหนด\n'
                            '• งานที่ถูกเลื่อน: จะแนะนำก้าวเริ่มต้น 10 นาที เพื่อลดแรงต้าน',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
                              color: AppColors.textSecondary,
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
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                ),
                borderRadius: AppRadius.smRadius,
                boxShadow: AppShadows.primaryGlow,
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Nudge',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_outlined, size: 20, color: AppColors.textSecondary),
                  if (_nudgePreview?['decision'] != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.rose,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'ศูนย์แจ้งเตือน Nudge',
              onPressed: _showNotificationCenter,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: IconButton(
              icon: const Icon(Icons.format_list_bulleted_rounded, size: 20, color: AppColors.textSecondary),
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
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
              tooltip: 'รีเฟรช',
              onPressed: _fetchDashboard,
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.cardSurfaceElevated,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.user.lineUserId != null
                    ? AppColors.lineGreen.withValues(alpha: 0.15)
                    : AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.user.lineUserId != null ? AppColors.lineGreen : AppColors.primary,
                  width: 1.5,
                ),
              ),
              child: Icon(
                widget.user.lineUserId != null ? Icons.chat_bubble_rounded : Icons.person_rounded,
                size: 18,
                color: widget.user.lineUserId != null ? AppColors.lineGreen : AppColors.primaryLight,
              ),
            ),
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
                      widget.user.lineUserId != null ? 'LINE Connected' : 'Guest User',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user.lineUserId ?? 'ID #${widget.user.id}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AppColors.rose),
                    SizedBox(width: 8),
                    Text('ออกจากระบบ', style: TextStyle(color: AppColors.rose)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
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
                        const Icon(Icons.error_outline, size: 48, color: AppColors.rose),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
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
                  color: AppColors.primary,
                  child: Stack(
                    children: [
                      // Ambient Cyber-Zen radial glow behind hero
                      Positioned(
                        top: -80,
                        left: 0,
                        right: 0,
                        height: 320,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.topCenter,
                              radius: 1.0,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.12),
                                AppColors.teal.withValues(alpha: 0.04),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
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
                    ],
                  ),
                ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.pillRadius,
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          ),
          boxShadow: AppShadows.primaryGlow,
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          foregroundColor: Colors.white,
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
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text(
            'เพิ่ม Task',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
