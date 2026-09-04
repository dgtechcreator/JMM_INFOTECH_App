import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class TaskAssignmentScreen extends StatefulWidget {
  const TaskAssignmentScreen({super.key, this.autoOpenSheet = false});
  final bool autoOpenSheet;

  @override
  State<TaskAssignmentScreen> createState() => _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends State<TaskAssignmentScreen> {
  final _service = TaskService();
  List<Map<String, dynamic>> _tasks = [];
  List<EmployeeSummary> _employees = [];
  List<Map<String, dynamic>> _priorities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.autoOpenSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAssignSheet());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_service.getTaskList(), _service.getEmployeesDropdown(), _service.getTaskPriorityDropdown()]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<Map<String, dynamic>>;
        _employees = results[1] as List<EmployeeSummary>;
        _priorities = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openAssignSheet() async {
    final titleController = TextEditingController();
    int? employeeId;
    int? priorityId;
    DateTime? dueDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Assign New Task', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 16),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Task title')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      hint: const Text('Assign to'),
                      items: _employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setSheetState(() => employeeId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      hint: const Text('Priority'),
                      items: _priorities.map((p) => DropdownMenuItem(value: p['Id'] as int, child: Text('${p['Name']}', overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setSheetState(() => priorityId = v),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(dueDate == null ? 'Due date' : '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'),
                      onPressed: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (picked != null) setSheetState(() => dueDate = picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty || employeeId == null) {
                          showSnack(context, 'Title and assignee are required.', isError: true);
                          return;
                        }
                        try {
                          await _service.assignTask(
                            title: titleController.text.trim(),
                            taskPriority: priorityId ?? 0,
                            assignToEmployeeId: employeeId!,
                            dueDate: dueDate?.toIso8601String(),
                            status: 1,
                          );
                          if (context.mounted) Navigator.pop(context);
                          if (mounted) {
                            showSnack(this.context, 'Task assigned.');
                            _load();
                          }
                        } catch (e) {
                          if (context.mounted) showSnack(context, e.toString(), isError: true);
                        }
                      },
                      child: const Text('Assign Task'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Management')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openAssignSheet, icon: const Icon(Icons.add), label: const Text('Assign')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _tasks.isEmpty
              ? const EmptyState(message: 'No tasks yet.', icon: Icons.checklist_outlined)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tasks.length,
                    itemBuilder: (context, i) {
                      final t = _tasks[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text('${t['Title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${t['AssignTo'] ?? ''} · ${t['ProjectName'] ?? ''} · Due ${t['DueDate'] ?? '-'}'),
                          trailing: StatusBadge(status: '${t['Status'] ?? ''}'),
                          onTap: () async {
                            final id = int.tryParse('${t['ID']}');
                            if (id == null) return;
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete task?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await _service.deleteTask(id);
                                if (mounted) {
                                  showSnack(this.context, 'Task deleted.');
                                  _load();
                                }
                              } catch (e) {
                                if (mounted) showSnack(this.context, e.toString(), isError: true);
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
