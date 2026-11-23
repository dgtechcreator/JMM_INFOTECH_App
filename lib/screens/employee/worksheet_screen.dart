import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../models/worksheet_models.dart';
import '../../services/worksheet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// My Worksheet: for each day, one or more rows of project + task name + short description + hours.
/// Same Timesheet data as the web "My Worksheet" page and the admin Worksheet Report. A Pending entry can be
/// edited or deleted; once the manager approves/rejects it, it is read-only.
class WorksheetScreen extends StatefulWidget {
  const WorksheetScreen({super.key});

  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen> {
  final _service = WorksheetService();

  DateTime _date = _dateOnly(DateTime.now());
  WorksheetSummary? _summary;
  List<WorksheetEntry> _entries = [];
  List<WorksheetProject> _projects = [];
  bool _loading = true;
  String? _error;

  DateTime get _today => _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool spinner = true}) async {
    if (spinner) setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>([
        _service.getSummary(_date),
        _service.getMyWorksheet(_date, _date),
        _service.getMyProjects(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as WorksheetSummary;
        _entries = results[1] as List<WorksheetEntry>;
        _projects = results[2] as List<WorksheetProject>;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load your worksheet.';
        _loading = false;
      });
    }
  }

  void _goTo(DateTime d) {
    final day = _dateOnly(d);
    if (day.isAfter(_today)) return;
    setState(() => _date = day);
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _today.subtract(const Duration(days: 365)),
      lastDate: _today,
    );
    if (picked != null) _goTo(picked);
  }

  Future<void> _openForm([WorksheetEntry? entry]) async {
    if (_projects.isEmpty) {
      showSnack(context, 'You are not tagged to any project yet. Ask your admin to add you to a project team.', isError: true);
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EntrySheet(service: _service, projects: _projects, date: _date, entry: entry),
    );
    if (saved == true) _load(spinner: false);
  }

  Future<void> _delete(WorksheetEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('${e.taskName.isEmpty ? e.projectName : e.taskName} - ${formatWorkedHours(e.hours)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteEntry(e.id);
      if (mounted) _load(spinner: false);
    } catch (err) {
      if (mounted) showSnack(context, err.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Worksheet')),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add work'),
            ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: () => _load(spinner: false),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    children: [
                      _dateBar(),
                      const SizedBox(height: 12),
                      _weekStrip(),
                      const SizedBox(height: 12),
                      _statCards(),
                      const SizedBox(height: 20),
                      _dayHeader(),
                      if (_entries.isEmpty)
                        const EmptyState(message: 'Nothing logged for this day yet.\nTap "Add work" to log your first task.', icon: Icons.edit_note_outlined)
                      else
                        ..._entries.map(_entryCard),
                      if ((_summary?.projects ?? const <WorksheetProjectHours>[]).isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const SectionHeader(title: 'This month by project'),
                        _monthProjects(),
                      ],
                    ],
                  ),
                ),
    );
  }

  // ---------------- pieces ----------------

  Widget _dateBar() {
    final isToday = _date == _today;
    return Row(
      children: [
        IconButton(onPressed: () => _goTo(_date.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(isToday ? 'Today' : dateGroupLabel(_date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(formatDate(worksheetIso(_date)), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: _date.isBefore(_today) ? () => _goTo(_date.add(const Duration(days: 1))) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _weekStrip() {
    final week = _summary?.week ?? const <WorksheetWeekDay>[];
    if (week.isEmpty) return const SizedBox.shrink();
    final selected = worksheetIso(_date);
    final today = worksheetIso(_today);
    return Row(
      children: [
        for (final d in week)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: d.date.compareTo(today) > 0 ? null : () => _goTo(DateTime.parse(d.date)),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: d.date == selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: d.date == today && d.date != selected ? AppColors.primary : AppColors.border),
                  ),
                  child: Opacity(
                    opacity: d.date.compareTo(today) > 0 ? 0.4 : 1,
                    child: Column(
                      children: [
                        Text(d.dayName, style: TextStyle(fontSize: 10, color: d.date == selected ? Colors.white70 : AppColors.textSecondary)),
                        Text('${d.dayNo}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: d.date == selected ? Colors.white : AppColors.textPrimary)),
                        Text(
                          d.hours > 0 ? formatWorkedHours(d.hours) : ' ',
                          style: TextStyle(fontSize: 9, color: d.date == selected ? Colors.white : AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statCards() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    final pct = (s.dayHours / s.standardHours).clamp(0.0, 1.0);
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Selected day', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      s.dayHours >= s.standardHours ? 'Target of ${formatWorkedHours(s.standardHours)} reached' : '${formatWorkedHours(s.standardHours - s.dayHours)} to reach ${formatWorkedHours(s.standardHours)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(formatWorkedHours(s.dayHours), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: s.dayHours >= s.standardHours ? AppColors.success : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: StatCard(label: 'This week', value: formatWorkedHours(s.weekHours), color: AppColors.info)),
            const SizedBox(width: 10),
            Expanded(child: StatCard(label: 'This month', value: formatWorkedHours(s.monthHours), color: AppColors.success)),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Month: approved ${formatWorkedHours(s.monthApproved)} · pending ${formatWorkedHours(s.monthPending)}'
            '${s.monthRejected > 0 ? ' · rejected ${formatWorkedHours(s.monthRejected)}' : ''} · ${s.monthDaysLogged} day(s) logged',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _dayHeader() {
    final total = _entries.fold<double>(0, (a, e) => a + e.hours);
    return SectionHeader(
      title: 'Work on this day',
      action: _entries.isEmpty ? null : Text('Total ${formatWorkedHours(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _entryCard(WorksheetEntry e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.taskName.isEmpty ? '(no task name)' : e.taskName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(e.projectName, style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w500)),
                  if (e.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(e.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                  if (e.status == 'Rejected' && e.rejectReason.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Reason: ${e.rejectReason}', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(formatWorkedHours(e.hours), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(width: 10),
                      StatusBadge(status: e.status),
                    ],
                  ),
                ],
              ),
            ),
            if (e.canEdit)
              Column(
                children: [
                  IconButton(visualDensity: VisualDensity.compact, onPressed: () => _openForm(e), icon: const Icon(Icons.edit_outlined, size: 20)),
                  IconButton(visualDensity: VisualDensity.compact, onPressed: () => _delete(e), icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _monthProjects() {
    final list = _summary!.projects;
    final max = list.fold<double>(0, (a, p) => p.hours > a ? p.hours : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final p in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(value: max > 0 ? p.hours / max : 0, minHeight: 8, backgroundColor: AppColors.border, color: const Color(0xFF7C5CFC)),
                        ),
                      ),
                    ),
                    SizedBox(width: 60, child: Text(formatWorkedHours(p.hours), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit form (bottom sheet). Pops `true` once the entry is saved.
class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.service, required this.projects, required this.date, this.entry});

  final WorksheetService service;
  final List<WorksheetProject> projects;
  final DateTime date;
  final WorksheetEntry? entry;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  int? _projectId;
  List<WorksheetTask> _tasks = [];
  final _taskCtl = TextEditingController();
  final _hoursCtl = TextEditingController();
  final _descCtl = TextEditingController();
  bool _saving = false;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _projectId = widget.projects.any((p) => p.id == e.projectId) ? e.projectId : null;
      _taskCtl.text = e.taskName;
      _hoursCtl.text = e.hours == e.hours.roundToDouble() ? e.hours.toStringAsFixed(0) : e.hours.toString();
      _descCtl.text = e.description;
    } else if (widget.projects.length == 1) {
      _projectId = widget.projects.first.id;
    }
    if (_projectId != null) _loadTasks();
  }

  @override
  void dispose() {
    _taskCtl.dispose();
    _hoursCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final id = _projectId;
    if (id == null) return;
    try {
      final tasks = await widget.service.getMyTasks(id);
      if (mounted && _projectId == id) setState(() => _tasks = tasks);
    } catch (_) {
      // Suggestions are a nicety - never block the form on them.
    }
  }

  void _quickHours(double h) => setState(() => _hoursCtl.text = h == h.roundToDouble() ? h.toStringAsFixed(0) : h.toString());

  Future<void> _save() async {
    final hours = double.tryParse(_hoursCtl.text.trim().replaceAll(',', '.'));
    final taskName = _taskCtl.text.trim();
    if (_projectId == null || taskName.isEmpty || hours == null || hours <= 0) {
      showSnack(context, 'Project, task name and hours are required.', isError: true);
      return;
    }
    if (hours > 24) {
      showSnack(context, 'Hours cannot be more than 24.', isError: true);
      return;
    }
    // Link to an assigned task only when the typed name is exactly that task's title.
    final linked = _tasks.where((t) => t.title == taskName).toList();
    setState(() => _saving = true);
    try {
      await widget.service.saveEntry(
        id: widget.entry?.id ?? 0,
        projectId: _projectId!,
        taskId: linked.isNotEmpty ? linked.first.id : null,
        taskName: taskName,
        date: widget.date,
        hours: hours,
        description: _descCtl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_editing ? 'Edit entry' : 'Add work', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(formatDate(worksheetIso(widget.date)), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _projectId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Project *'),
              items: widget.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) {
                setState(() {
                  _projectId = v;
                  _tasks = [];
                });
                _loadTasks();
              },
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _taskCtl.text),
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                return _tasks.map((t) => t.title).where((t) => q.isEmpty || t.toLowerCase().contains(q));
              },
              onSelected: (v) => _taskCtl.text = v,
              fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                controller: controller,
                focusNode: focus,
                maxLength: 200,
                onChanged: (v) => _taskCtl.text = v,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Task name *', hintText: 'e.g. Gate-in duplicate validation', counterText: ''),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hoursCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Hours *', hintText: 'e.g. 2.5'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final h in const [0.5, 1.0, 2.0, 4.0, 8.0])
                  ActionChip(label: Text(h < 1 ? '${(h * 60).round()}m' : '${h.toInt()}h'), onPressed: () => _quickHours(h)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtl,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'What did you do? (short description)', alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_editing ? 'Update entry' : 'Add to worksheet'),
            ),
          ],
        ),
      ),
    );
  }
}
