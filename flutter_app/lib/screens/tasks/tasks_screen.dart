import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getTasks();
      setState(() { _tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []); _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    await ApiService.updateTaskStatus(id, status);
    _load();
  }

  List<Map<String, dynamic>> _filtered(String status) =>
      status == 'all' ? _tasks : _tasks.where((t) => t['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: ['pending', 'in_progress', 'completed']
                  .map((s) => _taskList(_filtered(s)))
                  .toList(),
            ),
    );
  }

  Widget _taskList(List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) return const Center(child: Text('No tasks'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (ctx, i) {
        final t = tasks[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _priorityChip(t['priority']),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  ],
                ),
                if (t['description'] != null) ...[
                  const SizedBox(height: 6),
                  Text(t['description'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(t['assigned_by_name'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (t['due_date'] != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(t['due_date'].toString().split('T')[0], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                    const Spacer(),
                    if (t['status'] == 'pending')
                      TextButton(onPressed: () => _updateStatus(t['id'], 'in_progress'), child: const Text('Start')),
                    if (t['status'] == 'in_progress')
                      TextButton(onPressed: () => _updateStatus(t['id'], 'completed'), child: const Text('Done', style: TextStyle(color: AppTheme.success))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _priorityChip(String? priority) {
    Color c = Colors.grey;
    if (priority == 'high' || priority == 'urgent') c = AppTheme.error;
    if (priority == 'medium') c = AppTheme.warning;
    if (priority == 'low') c = AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(priority ?? 'low', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
