import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import 'add_task_screen.dart';
import 'focus_timer_screen.dart';
import 'task_detail_screen.dart';

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
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
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
            backgroundColor: Colors.indigo.shade800,
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
          backgroundColor: Color(0xFF10B981),
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

    if (task.isCompleted) {
      text = 'เสร็จสิ้น';
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
    } else if (task.isOverdue) {
      text = 'เกินกำหนด ${-task.daysRemaining} วัน';
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
    } else if (task.isDueToday) {
      text = 'ครบกำหนดวันนี้';
      bgColor = Colors.amber.shade100;
      textColor = Colors.amber.shade900;
    } else {
      text = 'เหลืออีก ${task.daysRemaining} วัน';
      bgColor = task.daysRemaining <= 2
          ? Colors.orange.shade50
          : Colors.indigo.shade50;
      textColor = task.daysRemaining <= 2
          ? Colors.orange.shade800
          : Colors.indigo.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
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

  Color _getImportanceColor(int importance) {
    switch (importance) {
      case 5:
        return Colors.red.shade600;
      case 4:
        return Colors.orange.shade700;
      case 3:
        return Colors.amber.shade800;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nudge — รายการ Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTasks,
            tooltip: 'รีเฟรชรายการ',
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
                          onPressed: _fetchTasks,
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  ),
                )
              : _tasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.indigo.shade50,
                              ),
                              child: Icon(Icons.spa_outlined,
                                  size: 36, color: Colors.indigo.shade400),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ยังไม่มีงานที่ต้องทำในตอนนี้ 🌱',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'เริ่มต้นวางแผนอย่างสบายใจ โดยไม่มีความกดดัน\nกดปุ่มด้านล่างเพื่อสร้าง Task แรกของคุณ',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, height: 1.4, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchTasks,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          final isActionLoading =
                              _actionLoadingTaskIds.contains(task.id);
                          final importanceColor =
                              _getImportanceColor(task.importance);

                          return Card(
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: task.isPotentiallyAvoided && !task.isCompleted
                                    ? Colors.amber.shade300
                                    : task.isCompleted
                                        ? Colors.green.shade200
                                        : Colors.grey.shade200,
                                width: task.isPotentiallyAvoided && !task.isCompleted ? 1.5 : 1.0,
                              ),
                            ),
                            color: task.isCompleted
                                ? Colors.grey.shade50
                                : task.isPotentiallyAvoided
                                    ? const Color(0xFFFFFDF5)
                                    : Colors.white,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openTaskDetail(task),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: isActionLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Icon(
                                                task.isCompleted
                                                    ? Icons.check_circle
                                                    : Icons.radio_button_unchecked,
                                                color: task.isCompleted
                                                    ? Colors.green
                                                    : Colors.grey,
                                              ),
                                        onPressed: isActionLoading
                                            ? null
                                            : () => _toggleTaskStatus(task),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration: task.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: task.isCompleted
                                                ? Colors.grey
                                                : Colors.black87,
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.amber.shade300),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.warning_amber_rounded,
                                              size: 16,
                                              color: Colors.orange.shade900),
                                          const SizedBox(width: 6),
                                          Text(
                                            '⚠️ อาจกำลังถูกเลื่อนซ้ำ',
                                            style: TextStyle(
                                              color: Colors.orange.shade900,
                                              fontWeight: FontWeight.bold,
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
                                      Icon(Icons.calendar_today_outlined,
                                          size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Deadline: ${_formatDate(task.deadline)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: importanceColor.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'สำคัญ: ${task.importance}/5',
                                          style: TextStyle(
                                            color: importanceColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.timer_outlined,
                                          size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'เวลา: ${task.estimatedMinutes} นาที',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      if (task.postponeCount > 0) ...[
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'เลื่อนแล้ว ${task.postponeCount} ครั้ง',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (!task.isCompleted) ...[
                                        IconButton(
                                          tooltip: 'เริ่มโฟกัส 10 นาที',
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(
                                            Icons.play_circle_fill_rounded,
                                            color: Color(0xFF6366F1),
                                            size: 28,
                                          ),
                                          onPressed: isActionLoading
                                              ? null
                                              : () => _startFocusSession(task),
                                        ),
                                        const SizedBox(width: 4),
                                        OutlinedButton.icon(
                                          onPressed: isActionLoading
                                              ? null
                                              : () => _confirmAndPostponeTask(task),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
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
                        );
                      },
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
            _fetchTasks();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('เพิ่ม Task'),
      ),
    );
  }
}
