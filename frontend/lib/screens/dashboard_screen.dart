import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import 'add_task_screen.dart';
import 'task_list_screen.dart';
import 'focus_timer_screen.dart';
import 'task_detail_screen.dart';

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
      setState(() {
        _dashboardData = data;
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
          apiClient: _apiClient,
        ),
      ),
    );
    // Reload dashboard after returning from focus session
    _loadDashboard();
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
          apiClient: _apiClient,
        ),
      ),
    );
    if (result == true) {
      _loadDashboard();
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
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade400),
              const SizedBox(height: 12),
              const Text(
                'ไม่มีงานค้างในตอนนี้',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'คุณจัดการงานสำคัญหมดแล้ว พักผ่อนหรือเพิ่ม Task ใหม่ได้ตลอดเวลา',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nudge'),
        actions: [
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
