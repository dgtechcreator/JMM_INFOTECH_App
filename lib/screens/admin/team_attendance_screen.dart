import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../services/attendance_service.dart';
import '../../services/task_service.dart';
import '../../widgets/common.dart';

class TeamAttendanceScreen extends StatefulWidget {
  const TeamAttendanceScreen({super.key, this.autoOpenSheet = false});
  final bool autoOpenSheet;

  @override
  State<TeamAttendanceScreen> createState() => _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends State<TeamAttendanceScreen> {
  final _attendanceService = AttendanceService();
  final _taskService = TaskService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.autoOpenSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRegularizeSheet());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _attendanceService.getTeamAttendanceList(search: _searchController.text.trim());
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openRegularizeSheet({Map<String, dynamic>? existing}) async {
    final employees = await _taskService.getEmployeesDropdown();
    if (!mounted) return;
    int? employeeId = existing != null ? existing['EmployeeID'] as int? : null;
    DateTime date = DateTime.now();
    String status = 'Present';
    final remarksController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(existing != null ? 'Regularize Attendance' : 'Mark Attendance', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: employeeId,
                    isExpanded: true,
                    hint: const Text('Employee'),
                    items: employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: existing != null ? null : (v) => setSheetState(() => employeeId = v),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text('${date.day}/${date.month}/${date.year}'),
                    onPressed: existing != null ? null : () async {
                      final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime.now());
                      if (picked != null) setSheetState(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    items: const ['Present', 'HalfDay', 'Absent', 'OnLeave', 'Holiday']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => status = v ?? 'Present'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: remarksController, decoration: const InputDecoration(labelText: 'Remarks')),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (employeeId == null) {
                        showSnack(context, 'Select an employee.', isError: true);
                        return;
                      }
                      try {
                        await _attendanceService.regularizeAttendance(
                          attendanceId: existing != null ? existing['AttendanceID'] as int? : null,
                          employeeId: employeeId!,
                          attendanceDate: date.toIso8601String(),
                          statusId: status,
                          remarks: remarksController.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          showSnack(this.context, 'Attendance updated.');
                          _load();
                        }
                      } catch (e) {
                        if (context.mounted) showSnack(context, e.toString(), isError: true);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
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
      appBar: AppBar(title: const Text('Team Attendance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRegularizeSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Mark Attendance'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search employee...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.filter_alt_outlined), onPressed: _load),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _rows.isEmpty
                        ? const EmptyState(message: 'No attendance records found.')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _rows.length,
                              itemBuilder: (context, i) {
                                final r = _rows[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text('${r['EmployeeName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text('${formatDate(r['AttendanceDate']?.toString())} · ${formatTime(r['PunchInTime']?.toString())} → ${formatTime(r['PunchOutTime']?.toString())}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        StatusBadge(status: '${r['StatusID'] ?? ''}'),
                                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _openRegularizeSheet(existing: r)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
