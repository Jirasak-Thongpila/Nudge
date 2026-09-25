import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'add_task_screen.dart';
import 'focus_timer_screen.dart';
import 'task_detail_screen.dart';

enum TaskListFilter {
  all,
  active,
  avoided,
  completed,
}

class TaskListScreen extends StatefulWidget {
  final ApiClient apiClient;
  final User user;

  const TaskListScreen({
    super.key,
    required this.apiClient,
    required this.user,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _actionLoadingTaskIds = {};
  TaskListFilter _currentFilter = TaskListFilter.all;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tasks = await widget.apiClient.getTasks();
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleTaskStatus(Task task) async {
    final newStatus = task.isCompleted ? 'NOT_STARTED' : 'COMPLETED';

    setState(() {
      _actionLoadingTaskIds.add(task.id);
    });

    try {
      final updated = await widget.apiClient.updateTaskStatus(task.id, newStatus);
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = updated;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเปลี่ยนสถานะได้: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoadingTaskIds.remove(task.id);
        });
      }
    }
  }

  Future<void> _confirmAndPostponeTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.cardRadius)),
        title: const Text('เลื่อนงานนี้ไปก่อน?'),
        content: const Text(
          'คุณกำลังเลือกที่จะเลื่อนงานนี้อย่างตั้งใจ (Explicit Postpone)\n\nระบบจะบันทึกข้อมูลเพื่อช่วยตรวจจับรูปแบบความยากในการเริ่ม และช่วยแนะนำขั้นตอนที่เล็กลงในภายหลัง โดยไม่ตัดสินคุณ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.avoidedAmber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonRadius)),
            ),
            child: const Text('เลื่อนไปก่อน'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _actionLoadingTaskIds.add(task.id);
    });

    try {
      final updated = await widget.apiClient.postponeTask(task.id);
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = updated;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'บันทึกการเลื่อนงาน "${task.title}" แล้ว (เลื่อนไปแล้ว ${updated.postponeCount} ครั้ง)',
            ),
            backgroundColor: AppColors.primaryIndigo,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเลื่อนงานได้: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionLoadingTaskIds.remove(task.id);
        });
      }
    }
  }

  Future<void> _startFocusSession(Task task) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FocusTimerScreen(
          task: task,
          apiClient: widget.apiClient,
        ),
      ),
    );
    _fetchTasks();
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 บันทึกงานสำเร็จเรียบร้อยแล้ว!'),
          backgroundColor: AppColors.completedEmerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openTaskDetail(Task task) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          apiClient: widget.apiClient,
        ),
      ),
    );
    if (result == true) {
      _fetchTasks();
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDaysRemainingBadge(Task task) {
    String text;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (task.isCompleted) {
      text = 'เสร็จสิ้น';
      bgColor = AppColors.teal.withValues(alpha: 0.12);
      textColor = AppColors.tealLight;
      icon = Icons.check_circle_rounded;
    } else if (task.isOverdue) {
      text = 'เกินกำหนด ${-task.daysRemaining} วัน';
      bgColor = AppColors.rose.withValues(alpha: 0.15);
      textColor = AppColors.roseLight;
      icon = Icons.error_outline_rounded;
    } else if (task.isDueToday) {
      text = 'ครบกำหนดวันนี้';
      bgColor = AppColors.amber.withValues(alpha: 0.15);
      textColor = AppColors.amberLight;
      icon = Icons.warning_amber_rounded;
    } else {
      text = 'เหลือ ${task.daysRemaining} วัน';
      bgColor = task.daysRemaining <= 2
          ? AppColors.amber.withValues(alpha: 0.15)
          : AppColors.primary.withValues(alpha: 0.15);
      textColor = task.daysRemaining <= 2 ? AppColors.amberLight : AppColors.primaryLight;
      icon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getImportanceColor(int importance) {
    switch (importance) {
      case 5:
        return AppColors.roseLight;
      case 4:
        return AppColors.amberLight;
      case 3:
        return AppColors.primaryLight;
      default:
        return AppColors.textMuted;
    }
  }

  List<Task> get _filteredTasks {
    switch (_currentFilter) {
      case TaskListFilter.all:
        return _tasks;
      case TaskListFilter.active:
        return _tasks.where((t) => !t.isCompleted).toList();
      case TaskListFilter.avoided:
        return _tasks.where((t) => t.isPotentiallyAvoided && !t.isCompleted).toList();
      case TaskListFilter.completed:
        return _tasks.where((t) => t.isCompleted).toList();
    }
  }

  Widget _buildFilterChips() {
    final allCount = _tasks.length;
    final activeCount = _tasks.where((t) => !t.isCompleted).length;
    final avoidedCount = _tasks.where((t) => t.isPotentiallyAvoided && !t.isCompleted).length;
    final completedCount = _tasks.where((t) => t.isCompleted).length;

    final filters = [
      (TaskListFilter.all, 'ทั้งหมด', allCount, Icons.dashboard_outlined),
      (TaskListFilter.active, 'กำลังทำ', activeCount, Icons.trending_up_rounded),
      (TaskListFilter.avoided, 'เลี่ยงบ่อย', avoidedCount, Icons.warning_amber_rounded),
      (TaskListFilter.completed, 'เสร็จแล้ว', completedCount, Icons.check_circle_outline_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: filters.map((item) {
          final isSelected = _currentFilter == item.$1;
          final count = item.$3;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _currentFilter = item.$1;
                });
              },
              borderRadius: AppRadius.pillRadius,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.cardSurfaceElevated : AppColors.cardSurface,
                  borderRadius: AppRadius.pillRadius,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.cardBorder,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected ? AppShadows.primaryGlow : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.$4,
                      size: 14,
                      color: isSelected
                          ? (item.$1 == TaskListFilter.avoided ? AppColors.amberLight : AppColors.primaryLight)
                          : (item.$1 == TaskListFilter.avoided ? AppColors.amber : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.cardSurfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.3) : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    switch (_currentFilter) {
      case TaskListFilter.avoided:
        title = 'ไม่มีงานที่ถูกเลื่อนซ้ำ 🎉';
        subtitle = 'คุณจัดการและเริ่มลงมือทำได้ดีมาก ไม่มีงานคั่งค้างในจุดนี้';
        icon = Icons.sentiment_very_satisfied_rounded;
        iconColor = AppColors.teal;
        break;
      case TaskListFilter.completed:
        title = 'ยังไม่มีงานที่เสร็จสิ้น';
        subtitle = 'ลองเริ่มโฟกัสก้าวแรก 10 นาที เพื่อเก็บความสำเร็จแรกของคุณ';
        icon = Icons.emoji_events_outlined;
        iconColor = AppColors.primaryLight;
        break;
      case TaskListFilter.active:
        title = 'ไม่มีงานที่กำลังทำอยู่';
        subtitle = 'กดปุ่มด้านล่างเพื่อเริ่มสร้าง Task ใหม่ได้ทันที';
        icon = Icons.task_alt_rounded;
        iconColor = AppColors.teal;
        break;
      case TaskListFilter.all:
        title = 'ยังไม่มีงานที่ต้องทำในตอนนี้ 🌱';
        subtitle = 'เริ่มต้นวางแผนอย่างสบายใจ โดยไม่มีความกดดัน\nกดปุ่มด้านล่างเพื่อสร้าง Task แรกของคุณ';
        icon = Icons.spa_outlined;
        iconColor = AppColors.primaryLight;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.15),
                border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 38, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _filteredTasks;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      appBar: AppBar(
        title: const Text(
          'Nudge — รายการ Task',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
              onPressed: _fetchTasks,
              tooltip: 'รีเฟรชรายการ',
            ),
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
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.rose),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _fetchTasks,
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildFilterChips(),
                    Expanded(
                      child: filteredTasks.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _fetchTasks,
                              color: AppColors.primary,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                                itemCount: filteredTasks.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final task = filteredTasks[index];
                                  final isActionLoading = _actionLoadingTaskIds.contains(task.id);
                                  final importanceColor = _getImportanceColor(task.importance);

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: task.isCompleted
                                          ? const Color(0xFF0C101A)
                                          : task.isPotentiallyAvoided
                                              ? const Color(0xFF19140C)
                                              : AppColors.cardSurface,
                                      borderRadius: BorderRadius.circular(AppRadius.cardRadius),
                                      border: Border.all(
                                        color: task.isPotentiallyAvoided && !task.isCompleted
                                            ? AppColors.amber.withValues(alpha: 0.6)
                                            : task.isCompleted
                                                ? AppColors.teal.withValues(alpha: 0.3)
                                                : AppColors.cardBorder,
                                        width: task.isPotentiallyAvoided && !task.isCompleted ? 1.5 : 1.0,
                                      ),
                                      boxShadow: task.isCompleted ? null : AppShadows.card,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(AppRadius.cardRadius),
                                        onTap: () => _openTaskDetail(task),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                    icon: isActionLoading
                                                        ? const SizedBox(
                                                            width: 22,
                                                            height: 22,
                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                          )
                                                        : Icon(
                                                            task.isCompleted
                                                                ? Icons.check_circle_rounded
                                                                : Icons.radio_button_unchecked_rounded,
                                                            color: task.isCompleted
                                                                ? AppColors.teal
                                                                : AppColors.textMuted,
                                                            size: 24,
                                                          ),
                                                    onPressed: isActionLoading ? null : () => _toggleTaskStatus(task),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      task.title,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w700,
                                                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                                        color: task.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _buildDaysRemainingBadge(task),
                                                ],
                                              ),

                                              // Empathetic Avoidance Badge per CONTEXT.md
                                              if (task.isPotentiallyAvoided && !task.isCompleted) ...[
                                                const SizedBox(height: 10),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF281907),
                                                    borderRadius: BorderRadius.circular(AppRadius.chipRadius),
                                                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.warning_amber_rounded,
                                                        size: 16,
                                                        color: AppColors.amberLight,
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        '⚠️ อาจกำลังถูกเลื่อนซ้ำ',
                                                        style: TextStyle(
                                                          color: AppColors.amberLight,
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],

                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textMuted),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Deadline: ${_formatDate(task.deadline)}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: importanceColor.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(AppRadius.chipRadius),
                                                      border: Border.all(color: importanceColor.withValues(alpha: 0.25)),
                                                    ),
                                                    child: Text(
                                                      'สำคัญ: ${task.importance}/5',
                                                      style: TextStyle(
                                                        color: importanceColor,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'เวลา: ${task.estimatedMinutes} นาที',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  if (task.postponeCount > 0) ...[
                                                    const SizedBox(width: 10),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.cardSurfaceElevated,
                                                        borderRadius: BorderRadius.circular(AppRadius.chipRadius),
                                                        border: Border.all(color: AppColors.cardBorder),
                                                      ),
                                                      child: Text(
                                                        'เลื่อนแล้ว ${task.postponeCount} ครั้ง',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const Spacer(),
                                                  if (!task.isCompleted) ...[
                                                    InkWell(
                                                      onTap: isActionLoading ? null : () => _startFocusSession(task),
                                                      borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          gradient: const LinearGradient(
                                                            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                                                          ),
                                                          borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                                          boxShadow: AppShadows.primaryGlow,
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 16),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'เริ่ม 10 นาที',
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w700,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    OutlinedButton.icon(
                                                      onPressed: isActionLoading ? null : () => _confirmAndPostponeTask(task),
                                                      style: OutlinedButton.styleFrom(
                                                        visualDensity: VisualDensity.compact,
                                                        foregroundColor: AppColors.textSecondary,
                                                        side: const BorderSide(color: AppColors.cardBorder),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
                                                        ),
                                                      ),
                                                      icon: const Icon(Icons.schedule, size: 14),
                                                      label: const Text(
                                                        'เลื่อนไปก่อน',
                                                        style: TextStyle(fontSize: 12),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.cardRadius),
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          ),
          boxShadow: AppShadows.primaryGlow,
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => AddTaskScreen(apiClient: widget.apiClient),
              ),
            );
            if (created == true) {
              _fetchTasks();
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'เพิ่ม Task',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
