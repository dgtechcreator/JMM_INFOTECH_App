import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../services/attendance_service.dart';
import '../../services/daily_log_service.dart';
import '../../services/overtime_service.dart';
import '../../services/reimbursement_service.dart';
import '../../services/salary_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'employee_salary_screen.dart';

/// Full admin-side profile for one employee — attendance, overtime, daily work logs, reimbursements
/// and salary history all in one place, plus a this-week worked-hours/OT rollup. Mirrors the web
/// admin's Employee Profile page (MVC.Web/Views/Master/EmployeeProfile.cshtml +
/// _EmployeeProfileTabs.cshtml with AllowAdminActions=true) — before this screen, tapping an employee
/// in the Team list only ever opened Salary (EmployeeSalaryScreen), even though the backend already had
/// per-employee endpoints for the rest.
///
/// Approve/reject actions for overtime and reimbursements stay on ApprovalsScreen (the team-wide queue)
/// rather than being duplicated here — this screen is read-only history for one person.
class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key, required this.employeeId, required this.employeeName});
  final int employeeId;
  final String employeeName;

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _attendanceService = AttendanceService();
  final _overtimeService = OvertimeService();
  final _dailyLogService = DailyLogService();
  final _reimbursementService = ReimbursementService();
  final _salaryService = SalaryService();

  bool _loading = true;
  String? _error;
  List<AttendanceRecord> _attendance = [];
  List<OvertimeLogRecord> _overtime = [];
  List<VisitLogRecord> _dailyLogs = [];
  List<ReimbursementRecord> _reimbursements = [];
  List<SalaryRecord> _salary = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    try {
      final results = await Future.wait([
        _attendanceService.getEmployeeAttendance(widget.employeeId, now.month, now.year),
        _overtimeService.getOvertimeAdminList(employeeId: widget.employeeId),
        _dailyLogService.getEmployeeVisitLogs(widget.employeeId),
        _reimbursementService.getReimbursementList(employeeId: widget.employeeId),
        _salaryService.getEmployeeSalaryList(widget.employeeId),
      ]);
      if (!mounted) return;
      setState(() {
        _attendance = results[0] as List<AttendanceRecord>;
        _overtime = results[1] as List<OvertimeLogRecord>;
        _dailyLogs = results[2] as List<VisitLogRecord>;
        _reimbursements = results[3] as List<ReimbursementRecord>;
        _salary = results[4] as List<SalaryRecord>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // Both AttendanceRecord.attendanceDate and OvertimeLogRecord.otDate come pre-formatted as
  // 'dd MMM yyyy' by their procs (USP_GetMyAttendance / USP_GetOvertimeAdminList), not ISO — so this
  // parses that display format back out for week-bucketing, falling back to ISO just in case a proc
  // ever changes shape, and returning null (skip the row) rather than throwing on anything unexpected.
  DateTime? _parseDisplayDate(String s) {
    if (s.isEmpty) return null;
    try {
      return DateFormat('d MMM yyyy').parseStrict(s);
    } catch (_) {
      return DateTime.tryParse(s);
    }
  }

  ({double hours, double otHours}) get _thisWeekSummary {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    var minutes = 0;
    for (final a in _attendance) {
      final d = _parseDisplayDate(a.attendanceDate);
      if (d != null && !d.isBefore(weekStart) && d.isBefore(weekEnd)) minutes += a.workedMinutes;
    }

    var otHours = 0.0;
    for (final o in _overtime) {
      if (o.statusId != 'Approved') continue;
      final d = _parseDisplayDate(o.otDate);
      if (d != null && !d.isBefore(weekStart) && d.isBefore(weekEnd)) otHours += o.hours;
    }

    return (hours: minutes / 60.0, otHours: otHours);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeName),
        bottom: _loading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Attendance'),
                  Tab(text: 'Overtime'),
                  Tab(text: 'Daily Log'),
                  Tab(text: 'Reimbursement'),
                  Tab(text: 'Salary'),
                ],
              ),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    _buildWeekSummary(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAttendanceTab(),
                          _buildOvertimeTab(),
                          _buildDailyLogTab(),
                          _buildReimbursementTab(),
                          _buildSalaryTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildWeekSummary() {
    final s = _thisWeekSummary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(child: StatCard(label: 'This Week — Worked', value: '${s.hours.toStringAsFixed(1)} hrs', color: AppColors.primaryDark, icon: Icons.schedule_outlined)),
          const SizedBox(width: 10),
          Expanded(child: StatCard(label: 'This Week — OT', value: '${s.otHours.toStringAsFixed(1)} hrs', color: AppColors.warning, icon: Icons.bolt_outlined)),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    if (_attendance.isEmpty) return const EmptyState(message: 'No attendance records this month.', icon: Icons.event_busy_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _attendance.length,
        itemBuilder: (context, i) {
          final a = _attendance[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(a.attendanceDate, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${a.punchInTime ?? '--:--'} → ${a.punchOutTime ?? '--:--'} · ${(a.workedMinutes / 60.0).toStringAsFixed(1)} hrs${a.remarks != null && a.remarks!.isNotEmpty ? '\n${a.remarks}' : ''}'),
              isThreeLine: a.remarks != null && a.remarks!.isNotEmpty,
              trailing: StatusBadge(status: a.statusId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOvertimeTab() {
    if (_overtime.isEmpty) return const EmptyState(message: 'No overtime logged.', icon: Icons.bolt_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _overtime.length,
        itemBuilder: (context, i) {
          final o = _overtime[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('${o.otDate} · ${o.hours} hrs', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: o.description != null && o.description!.isNotEmpty ? Text(o.description!) : null,
              trailing: StatusBadge(status: o.statusId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyLogTab() {
    if (_dailyLogs.isEmpty) return const EmptyState(message: 'No daily logs yet.', icon: Icons.assignment_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _dailyLogs.length,
        itemBuilder: (context, i) {
          final l = _dailyLogs[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(l.agenda, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${l.visitDate} · ${l.customerName} · ${l.projectName}${l.duration.isNotEmpty ? ' · ${l.duration}' : ''}'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReimbursementTab() {
    if (_reimbursements.isEmpty) return const EmptyState(message: 'No reimbursement requests yet.', icon: Icons.receipt_long_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reimbursements.length,
        itemBuilder: (context, i) {
          final r = _reimbursements[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('₹${r.amount.toStringAsFixed(0)} · ${r.category}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${r.expenseDate}${r.description.isNotEmpty ? '\n${r.description}' : ''}'),
              isThreeLine: r.description.isNotEmpty,
              trailing: StatusBadge(status: r.statusId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalaryTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Manage Salary'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeSalaryScreen(employeeId: widget.employeeId, employeeName: widget.employeeName))).then((_) => _load()),
            ),
          ),
        ),
        Expanded(
          child: _salary.isEmpty
              ? const EmptyState(message: 'No salary records yet.', icon: Icons.account_balance_wallet_outlined)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _salary.length,
                    itemBuilder: (context, i) {
                      final s = _salary[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${s.payMonth}/${s.payYear}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Due ₹${s.amountDue.toStringAsFixed(0)} · Paid ₹${s.amountPaid.toStringAsFixed(0)}'),
                          trailing: StatusBadge(status: s.balance <= 0 ? 'Paid' : 'Pending'),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
