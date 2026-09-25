import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/theme_toggle_button.dart';
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
  final bool showAppBar;

  const TaskListScreen({
    super.key,
    required this.apiClient,
    required this.user,
    this.showAppBar = true,
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

  Widget _buildImportanceBadge(int importance, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        'สำคัญ: $importance/5',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _sendLineNudge(Task task) async {
    setState(() {
      _actionLoadingTaskIds.add(task.id);
    });

    try {
      await widget.apiClient.sendLineActionNudge(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ส่ง Action Nudge สำหรับ "${task.title}" ไปยัง LINE OA เรียบร้อยแล้ว!'),
            backgroundColor: AppColors.lineGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถส่ง LINE Nudge ได้: $e'),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
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
                  color: isSelected ? context.colors.cardSurfaceElevated : context.colors.cardSurface,
                  borderRadius: AppRadius.pillRadius,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : context.colors.cardBorder,
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
                          : (item.$1 == TaskListFilter.avoided ? AppColors.amber : context.colors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? context.colors.textPrimary : context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : context.colors.cardSurfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.3) : context.colors.cardBorder,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? context.colors.textPrimary : context.colors.textSecondary,
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
    final colors = context.colors;
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
        iconColor = colors.isDark ? AppColors.primaryLight : AppColors.primary;
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
        iconColor = colors.isDark ? AppColors.primaryLight : AppColors.primary;
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
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
    final colors = context.colors;

    final content = _isLoading
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
                      Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
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
                                        ? (context.colors.isDark ? const Color(0xFF0C101A) : const Color(0xFFF1F5F9))
                                        : task.isPotentiallyAvoided
                                            ? (context.colors.isDark ? const Color(0xFF19140C) : const Color(0xFFFFFBEB))
                                            : context.colors.cardSurface,
                                    borderRadius: BorderRadius.circular(AppRadius.cardRadius),
                                    border: Border.all(
                                      color: task.isPotentiallyAvoided && !task.isCompleted
                                          ? AppColors.amber.withValues(alpha: 0.6)
                                          : task.isCompleted
                                              ? AppColors.teal.withValues(alpha: 0.3)
                                              : context.colors.cardBorder,
                                      width: task.isPotentiallyAvoided && !task.isCompleted ? 1.5 : 1.0,
                                    ),
                                    boxShadow: task.isCompleted ? null : context.colors.cardShadow,
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
                                                              : context.colors.textMuted,
                                                          size: 24,
                                                        ),
                                                  onPressed: isActionLoading ? null : () => _toggleTaskStatus(task),
                                                  tooltip: task.isCompleted ? 'ทำเครื่องหมายว่ายังไม่เสร็จ' : 'ทำเครื่องหมายว่าเสร็จแล้ว',
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        task.title,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w700,
                                                          color: task.isCompleted
                                                              ? context.colors.textMuted
                                                              : context.colors.textPrimary,
                                                          decoration: task.isCompleted
                                                              ? TextDecoration.lineThrough
                                                              : null,
                                                          decorationColor: context.colors.textMuted,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          Icon(Icons.calendar_today_rounded, size: 13, color: context.colors.textMuted),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            _formatDate(task.deadline),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              color: task.isOverdue && !task.isCompleted
                                                                  ? AppColors.rose
                                                                  : task.isDueToday && !task.isCompleted
                                                                      ? AppColors.amber
                                                                      : context.colors.textSecondary,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Icon(Icons.timer_outlined, size: 13, color: context.colors.textMuted),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            '${task.estimatedMinutes} นาที',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: context.colors.textSecondary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    _buildImportanceBadge(task.importance, importanceColor),
                                                    const SizedBox(height: 4),
                                                    _buildDaysRemainingBadge(task),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            if (task.isPotentiallyAvoided && !task.isCompleted) ...[
                                              const SizedBox(height: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.amber.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                                  border: Border.all(
                                                    color: AppColors.amber.withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.warning_amber_rounded,
                                                      size: 15,
                                                      color: AppColors.amber,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'อาจกำลังเลี่ยงงานนี้ (เลื่อน ${task.postponeCount} ครั้ง)',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppColors.amber,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            if (!task.isCompleted) ...[
                                              const SizedBox(height: 12),
                                              const Divider(height: 1, color: AppColors.cardBorder),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton.icon(
                                                    style: TextButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      foregroundColor: context.colors.textSecondary,
                                                    ),
                                                    icon: const Icon(Icons.schedule, size: 15),
                                                    label: const Text('เลื่อนไปก่อน', style: TextStyle(fontSize: 12)),
                                                    onPressed: isActionLoading ? null : () => _confirmAndPostponeTask(task),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  TextButton.icon(
                                                    style: TextButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      foregroundColor: AppColors.lineGreen,
                                                    ),
                                                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                                                    label: const Text('LINE Nudge', style: TextStyle(fontSize: 12)),
                                                    onPressed: isActionLoading ? null : () => _sendLineNudge(task),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  FilledButton.tonalIcon(
                                                    style: FilledButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                                      foregroundColor: AppColors.primaryLight,
                                                    ),
                                                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                                    label: const Text('เริ่ม 10 นาที', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    onPressed: () => _startFocusSession(task),
                                                  ),
                                                ],
                                              ),
                                            ],
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
              );

    if (!widget.showAppBar) {
      return Container(
        color: colors.bgCanvas,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(
        title: Text(
          'Nudge — รายการ Task',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          const ThemeToggleButton(),
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.cardBorder),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 20),
              onPressed: _fetchTasks,
              tooltip: 'รีเฟรชรายการ',
            ),
          ),
        ],
      ),
      body: content,
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
