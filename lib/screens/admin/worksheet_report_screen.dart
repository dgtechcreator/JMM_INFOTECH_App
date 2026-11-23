import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../models/worksheet_models.dart';
import '../../services/worksheet_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

enum _Period { today, week, month, lastMonth, last30 }

enum _View { project, employee, day, log }

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Admin Worksheet Report - who worked on which project / task and for how long, with totals, expected hours
/// and utilisation. Same numbers as the web "Worksheet Report" page (one stored procedure behind both).
class WorksheetReportScreen extends StatefulWidget {
  const WorksheetReportScreen({super.key});

  @override
  State<WorksheetReportScreen> createState() => _WorksheetReportScreenState();
}

class _WorksheetReportScreenState extends State<WorksheetReportScreen> {
  final _service = WorksheetService();

  _Period _period = _Period.month;
  _View _view = _View.project;
  int? _employeeId;
  int? _projectId;
  String? _status; // null = Pending + Approved
  List<WorksheetFilterOption> _employees = [];
  List<WorksheetFilterOption> _projects = [];
  WorksheetReport? _report;
  bool _loading = true;
  String? _error;

  static const _logCap = 300;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _load();
  }

  (DateTime, DateTime) get _range {
    final today = _dateOnly(DateTime.now());
    switch (_period) {
      case _Period.today:
        return (today, today);
      case _Period.week:
        return (today.subtract(Duration(days: today.weekday - 1)), today);
      case _Period.month:
        return (DateTime(today.year, today.month, 1), today);
      case _Period.lastMonth:
        return (DateTime(today.year, today.month - 1, 1), DateTime(today.year, today.month, 0));
      case _Period.last30:
        return (today.subtract(const Duration(days: 29)), today);
    }
  }

  Future<void> _loadOptions() async {
    try {
      final o = await _service.getFilterOptions();
      if (!mounted) return;
      setState(() {
        _employees = o.employees;
        _projects = o.projects;
      });
    } catch (_) {
      // The dropdowns are a convenience; the report itself still loads (and shows its own error if any).
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final (from, to) = _range;
    try {
      final r = await _service.getReport(from: from, to: to, employeeId: _employeeId, projectId: _projectId, status: _status);
      if (!mounted) return;
      setState(() {
        _report = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load the report.';
        _loading = false;
      });
    }
  }

  String _periodLabel(_Period p) {
    switch (p) {
      case _Period.today:
        return 'Today';
      case _Period.week:
        return 'This week';
      case _Period.month:
        return 'This month';
      case _Period.lastMonth:
        return 'Last month';
      case _Period.last30:
        return 'Last 30 days';
    }
  }

  void _drill({int? employeeId, int? projectId}) {
    setState(() {
      if (employeeId != null) _employeeId = employeeId;
      if (projectId != null) _projectId = projectId;
      _view = _View.log;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worksheet Report')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _filters(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.only(top: 40), child: LoadingView())
            else if (_error != null)
              ErrorView(message: _error!, onRetry: _load)
            else if (_report != null) ...[
              _kpis(_report!.kpi),
              const SizedBox(height: 14),
              _viewChips(),
              const SizedBox(height: 12),
              ..._rows(_report!),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------- filters ----------------

  Widget _filters() {
    final hasExtra = _employeeId != null || _projectId != null || _status != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in _Period.values)
                  ChoiceChip(
                    label: Text(_periodLabel(p)),
                    selected: _period == p,
                    showCheckmark: false,
                    labelStyle: TextStyle(color: _period == p ? Colors.white : AppColors.textPrimary, fontSize: 12),
                    onSelected: (_) {
                      setState(() => _period = p);
                      _load();
                    },
                  ),
              ],
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: hasExtra,
                title: Text(hasExtra ? 'Filters (active)' : 'More filters', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _employeeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Employee'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All employees')),
                      ..._employees.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) {
                      setState(() => _employeeId = v);
                      _load();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: _projectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Project'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All projects')),
                      ..._projects.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) {
                      setState(() => _projectId = v);
                      _load();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Hours to count'),
                    items: const [
                      DropdownMenuItem<String?>(value: null, child: Text('Pending + Approved')),
                      DropdownMenuItem<String?>(value: 'Approved', child: Text('Approved only')),
                      DropdownMenuItem<String?>(value: 'Pending', child: Text('Pending only')),
                      DropdownMenuItem<String?>(value: 'Rejected', child: Text('Rejected only')),
                      DropdownMenuItem<String?>(value: 'All', child: Text('Everything')),
                    ],
                    onChanged: (v) {
                      setState(() => _status = v);
                      _load();
                    },
                  ),
                  if (hasExtra)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _employeeId = null;
                            _projectId = null;
                            _status = null;
                          });
                          _load();
                        },
                        child: const Text('Clear filters'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- KPIs ----------------

  Widget _kpis(WorksheetKpi k) {
    final util = _projectId == null ? k.utilisation : null;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatCard(label: 'Total hours', value: formatWorkedHours(k.totalHours), color: AppColors.info, icon: Icons.schedule)),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'Utilisation',
                value: util == null ? '-' : '${util.round()}%',
                color: util == null ? AppColors.textSecondary : (util >= 90 ? AppColors.success : (util >= 60 ? AppColors.warning : AppColors.danger)),
                icon: Icons.speed_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: StatCard(label: 'People / projects', value: '${k.employeesLogged} / ${k.projectsWorked}', color: const Color(0xFF7C5CFC), icon: Icons.groups_outlined)),
            const SizedBox(width: 10),
            Expanded(child: StatCard(label: 'Days not logged', value: _projectId == null ? '${k.missingDays}' : '-', color: AppColors.danger, icon: Icons.event_busy_outlined)),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Approved ${formatWorkedHours(k.approvedHours)} · Pending ${formatWorkedHours(k.pendingHours)}'
            '${k.rejectedHours > 0 ? ' · Rejected ${formatWorkedHours(k.rejectedHours)}' : ''}'
            '${util != null ? ' · Expected ${formatWorkedHours(k.expectedHours)}' : ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _viewChips() {
    String label(_View v) {
      switch (v) {
        case _View.project:
          return 'By project';
        case _View.employee:
          return 'By employee';
        case _View.day:
          return 'By day';
        case _View.log:
          return 'Full log';
      }
    }

    return Wrap(
      spacing: 8,
      children: [
        for (final v in _View.values)
          ChoiceChip(
            label: Text(label(v)),
            selected: _view == v,
            showCheckmark: false,
            labelStyle: TextStyle(color: _view == v ? Colors.white : AppColors.textPrimary, fontSize: 12),
            onSelected: (_) => setState(() => _view = v),
          ),
      ],
    );
  }

  // ---------------- rows ----------------

  List<Widget> _rows(WorksheetReport r) {
    switch (_view) {
      case _View.project:
        return _projectRows(r);
      case _View.employee:
        return _employeeRows(r);
      case _View.day:
        return _dayRows(r);
      case _View.log:
        return _logRows(r);
    }
  }

  Widget _bar(double value, Color color) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: value.clamp(0.0, 1.0), minHeight: 7, backgroundColor: AppColors.border, color: color),
      );

  List<Widget> _projectRows(WorksheetReport r) {
    if (r.byProject.isEmpty) return const [EmptyState(message: 'No hours logged for these filters.')];
    final total = r.byProject.fold<double>(0, (a, p) => a + p.totalHours);
    return [
      for (final p in r.byProject)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _drill(projectId: p.projectId),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(formatWorkedHours(p.totalHours), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _bar(total > 0 ? p.totalHours / total : 0, AppColors.info),
                  const SizedBox(height: 6),
                  Text(
                    '${total > 0 ? (p.totalHours / total * 100).toStringAsFixed(1) : '0'}% · ${p.employees} people · ${p.days} days · ${p.entries} entries\n'
                    'Approved ${formatWorkedHours(p.approvedHours)} · Pending ${formatWorkedHours(p.pendingHours)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _employeeRows(WorksheetReport r) {
    if (r.byEmployee.isEmpty) return const [EmptyState(message: 'No employees for these filters.')];
    return [
      for (final e in r.byEmployee)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _drill(employeeId: e.employeeId),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (e.department.isNotEmpty) Text(e.department, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(formatWorkedHours(e.totalHours), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                  if (e.utilisation != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _bar(
                            e.utilisation! / 100,
                            e.utilisation! >= 90 ? AppColors.success : (e.utilisation! >= 60 ? AppColors.info : (e.utilisation! >= 30 ? AppColors.warning : AppColors.danger)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${e.utilisation!.round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${e.daysLogged} days logged · avg ${e.avgPerDay > 0 ? formatWorkedHours(e.avgPerDay) : '-'}/day · ${e.projects} project(s)'
                    '${e.expectedHours != null ? ' · expected ${formatWorkedHours(e.expectedHours!)}' : ''}\n'
                    'Approved ${formatWorkedHours(e.approvedHours)} · Pending ${formatWorkedHours(e.pendingHours)}'
                    '${(e.missingDays ?? 0) > 0 ? ' · ${e.missingDays} day(s) missed' : ''}',
                    style: TextStyle(fontSize: 11, color: (e.missingDays ?? 0) > 0 ? AppColors.danger : AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _dayRows(WorksheetReport r) {
    if (r.byDay.isEmpty) return const [EmptyState(message: 'No hours logged for these filters.')];
    final max = r.byDay.fold<double>(0, (a, d) => d.totalHours > a ? d.totalHours : a);
    return [
      for (final d in r.byDay)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${formatDate(d.date)}  ${d.dayName}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(formatWorkedHours(d.totalHours), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                _bar(max > 0 ? d.totalHours / max : 0, AppColors.primary),
                const SizedBox(height: 6),
                Text('${d.employees} people · ${d.entries} entries', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _logRows(WorksheetReport r) {
    if (r.detail.isEmpty) return const [EmptyState(message: 'No hours logged for these filters.')];
    final shown = r.detail.take(_logCap).toList();
    return [
      for (final w in shown)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(w.task.isEmpty ? '(no task name)' : w.task, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Text(formatWorkedHours(w.hours), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${w.employee} · ${w.project}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w500)),
                if (w.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(w.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
                if (w.status == 'Rejected' && w.rejectReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Reason: ${w.rejectReason}', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(formatDate(w.date), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 10),
                    StatusBadge(status: w.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (r.detail.length > _logCap)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('Showing the latest $_logCap of ${r.detail.length} entries. Narrow the dates or pick an employee/project to see the rest.',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
    ];
  }
}
