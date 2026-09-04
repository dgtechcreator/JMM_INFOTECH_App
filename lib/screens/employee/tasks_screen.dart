import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _service = TaskService();
  List<TaskItem> _tasks = [];
  List<TaskStatusOption> _statusOptions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_service.getMyTasks(), _service.getTaskStatusOptions()]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<TaskItem>;
        _statusOptions = results[1] as List<TaskStatusOption>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(TaskItem task, int newStatusId) async {
    try {
      await _service.updateMyTaskStatus(task.id, newStatusId);
      if (mounted) showSnack(context, 'Task updated.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _tasks.isEmpty
                  ? const EmptyState(message: 'No tasks assigned to you.', icon: Icons.checklist_rtl_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tasks.length,
                        itemBuilder: (context, i) => _taskCard(_tasks[i]),
                      ),
                    ),
    );
  }

  Widget _taskCard(TaskItem task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                StatusBadge(status: task.status),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (task.projectName.isNotEmpty) _metaChip(Icons.folder_outlined, task.projectName),
                if (task.priority.isNotEmpty) _metaChip(Icons.flag_outlined, task.priority),
                if (task.dueDate.isNotEmpty) _metaChip(Icons.event_outlined, task.dueDate),
              ],
            ),
            const SizedBox(height: 12),
            if (_statusOptions.isNotEmpty)
              Row(
                children: [
                  const Text('Status:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _statusOptions.any((s) => s.id == task.statusId) ? task.statusId : null,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                      items: _statusOptions.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) {
                        if (v != null) _updateStatus(task, v);
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
