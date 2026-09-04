import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/daily_log_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class DailyLogScreen extends StatefulWidget {
  const DailyLogScreen({super.key});

  @override
  State<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends State<DailyLogScreen> {
  final _service = DailyLogService();
  List<VisitLogRecord> _logs = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _projects = [];
  bool _loading = true;

  DateTime _visitDate = DateTime.now();
  int? _customerId;
  int? _projectId;
  final _agendaController = TextEditingController();
  final _durationController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _agendaController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_service.getMyVisitLogs(), _service.getCustomerDropdown(), _service.getProjectDropdown()]);
      if (!mounted) return;
      setState(() {
        _logs = results[0] as List<VisitLogRecord>;
        _customers = results[1] as List<Map<String, dynamic>>;
        _projects = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Could not load daily logs.', isError: true);
    }
  }

  Future<void> _submit() async {
    if (_customerId == null || _projectId == null || _agendaController.text.trim().isEmpty) {
      showSnack(context, 'Customer, project and agenda are required.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.saveVisitLog(
        visitDate: _visitDate.toIso8601String(),
        customerId: _customerId!,
        projectId: _projectId!,
        agenda: _agendaController.text.trim(),
        duration: _durationController.text.trim().isEmpty ? null : _durationController.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, 'Daily log saved.');
      _agendaController.clear();
      _durationController.clear();
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Log')),
      body: _loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Log today\'s work', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.event_outlined, size: 18),
                            label: Text('${_visitDate.day}/${_visitDate.month}/${_visitDate.year}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _visitDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 60)),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _visitDate = picked);
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _customerId,
                            isExpanded: true,
                            hint: const Text('Customer'),
                            items: _customers.map((c) => DropdownMenuItem(value: c['M_Common_ID'] as int, child: Text('${c['Name']}', overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _customerId = v),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _projectId,
                            isExpanded: true,
                            hint: const Text('Project'),
                            items: _projects.map((p) => DropdownMenuItem(value: p['ID'] as int, child: Text('${p['ProjectName']}', overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _projectId = v),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _durationController,
                            decoration: const InputDecoration(labelText: 'Duration (e.g. 2 hours)'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _agendaController,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'What did you work on?', alignLabelWithHint: true),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save Log'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'History'),
                  if (_logs.isEmpty)
                    const EmptyState(message: 'No daily logs yet.')
                  else
                    ..._logs.map((l) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(l.agenda),
                            subtitle: Text('${formatDate(l.visitDate)} · ${l.customerName} · ${l.projectName}'),
                            trailing: l.duration.isEmpty ? null : Text(l.duration, style: const TextStyle(color: AppColors.textSecondary)),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
