import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import 'add_task_screen.dart';

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
  final Set<int> _updatingTaskIds = {};

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
      _updatingTaskIds.add(task.id);
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
          _updatingTaskIds.remove(task.id);
        });
      }
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
                            Icon(Icons.checklist_rounded,
                                size: 64, color: Colors.indigo.shade200),
                            const SizedBox(height: 16),
                            const Text(
                              'ยังไม่มี Task ในระบบ',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'กดปุ่ม + ด้านล่างเพื่อเพิ่ม Task สำคัญที่คุณต้องการเริ่มทำ',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
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
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          final isUpdating = _updatingTaskIds.contains(task.id);
                          final importanceColor =
                              _getImportanceColor(task.importance);

                          return Card(
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: task.isCompleted
                                    ? Colors.green.shade200
                                    : Colors.grey.shade200,
                              ),
                            ),
                            color: task.isCompleted
                                ? Colors.grey.shade50
                                : Colors.white,
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
                                        icon: isUpdating
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
                                        onPressed: isUpdating
                                            ? null
                                            : () => _toggleTaskStatus(task),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
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
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildDaysRemainingBadge(task),
                                    ],
                                  ),
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
                                          color: importanceColor.withOpacity(0.12),
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
                                        'เวลาโดยประมาณ: ${task.estimatedMinutes} นาที',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
