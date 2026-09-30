import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../services/wfh_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Admin Work From Home: approve/reject, who's on WFH today (with a nudge), the monthly office-vs-WFH
/// report, and the reminder/limit policy. Web twin: Views/WfhManagement/Index.cshtml (same server service).
class WfhAdminScreen extends StatefulWidget {
  const WfhAdminScreen({super.key, this.initialTabIndex = 0});
  final int initialTabIndex;

  @override
  State<WfhAdminScreen> createState() => _WfhAdminScreenState();
}

class _WfhAdminScreenState extends State<WfhAdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const _WfhSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work From Home'),
        actions: [IconButton(tooltip: 'Reminders & limits', icon: const Icon(Icons.tune), onPressed: _openSettings)],
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Pending'), Tab(text: 'Today'), Tab(text: 'Monthly')]),
      ),
      body: TabBarView(controller: _tabController, children: const [WfhPendingList(), _WfhTodayTab(), _WfhMonthlyTab()]),
    );
  }
}

/// Pending WFH requests with Approve / Reject (+ optional note). Also used as the "WFH" tab of Approvals.
class WfhPendingList extends StatefulWidget {
  const WfhPendingList({super.key});

  @override
  State<WfhPendingList> createState() => _WfhPendingListState();
}

class _WfhPendingListState extends State<WfhPendingList> {
  final _service = WfhService();
  List<WfhRequest> _rows = [];
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
      final rows = await _service.getAdminList(status: 'Pending');
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _act(WfhRequest r, bool approve) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve WFH?' : 'Reject WFH?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.employeeName} · ${_range(r)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(controller: controller, decoration: InputDecoration(labelText: approve ? 'Note for the employee (optional)' : 'Reason (shown to the employee)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Approve' : 'Reject', style: TextStyle(color: approve ? AppColors.success : AppColors.danger)),
          ),
        ],
      ),
    );
    final remarks = controller.text.trim();
    controller.dispose();
    if (confirmed != true) return;
    try {
      await _service.action(r.id, approve ? 'Approved' : 'Rejected', remarks: remarks);
      if (mounted) showSnack(context, approve ? 'WFH approved.' : 'WFH rejected.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
      _load();
    }
  }

  static String _range(WfhRequest r) =>
      r.fromDate == r.toDate ? formatDate(r.fromDate) : '${formatDate(r.fromDate)} → ${formatDate(r.toDate)}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const EmptyState(message: 'No pending Work From Home requests.', icon: Icons.home_work_outlined);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final r = _rows[i];
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
                      Expanded(child: Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('${r.totalDays} day${r.totalDays == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_range(r), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if (r.reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.reason, style: const TextStyle(fontSize: 13))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => _act(r, false), style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger), child: const Text('Reject'))),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton(onPressed: () => _act(r, true), child: const Text('Approve'))),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WfhTodayTab extends StatefulWidget {
  const _WfhTodayTab();

  @override
  State<_WfhTodayTab> createState() => _WfhTodayTabState();
}

class _WfhTodayTabState extends State<_WfhTodayTab> {
  final _service = WfhService();
  List<WfhBoardEntry> _rows = [];
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
      final rows = await _service.getTodayBoard();
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _remind(WfhBoardEntry e) async {
    try {
      await _service.remindEmployee(e.requestId);
      if (mounted) showSnack(context, 'Reminder sent to ${e.employeeName}.');
    } on ApiException catch (err) {
      if (mounted) showSnack(context, err.message, isError: true);
    }
  }

  Color _stateColor(String s) {
    switch (s) {
      case 'Working':
        return AppColors.info;
      case 'Completed':
        return AppColors.success;
      case 'Not started':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const EmptyState(message: 'Nobody has an approved WFH day today.', icon: Icons.home_work_outlined);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final e = _rows[i];
          final color = _stateColor(e.workState);
          final canRemind = e.workState == 'Not started' || e.workState == 'Working';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.employeeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          e.punchInTime == null
                              ? 'Has not started yet'
                              : 'Started ${formatTime(e.punchInTime)}${e.punchOutTime != null ? ' · ended ${formatTime(e.punchOutTime)}' : ''} · ${e.workedMinutes ~/ 60}h ${(e.workedMinutes % 60).toString().padLeft(2, '0')}m',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(e.workState, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  if (canRemind)
                    IconButton(onPressed: () => _remind(e), icon: const Icon(Icons.notifications_active_outlined), tooltip: 'Send reminder'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WfhMonthlyTab extends StatefulWidget {
  const _WfhMonthlyTab();

  @override
  State<_WfhMonthlyTab> createState() => _WfhMonthlyTabState();
}

class _WfhMonthlyTabState extends State<_WfhMonthlyTab> {
  final _service = WfhService();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<WfhMonthlyRow> _rows = [];
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
      final rows = await _service.getMonthlySummary(month: _month.month, year: _month.year);
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = _month.year == DateTime.now().year && _month.month == DateTime.now().month;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
              Text(DateFormat('MMMM yyyy').format(_month), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              IconButton(onPressed: isCurrent ? null : () => _shift(1), icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Days count only when the person punched in (office or WFH).', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : _rows.isEmpty
                      ? const EmptyState(message: 'No employees.', icon: Icons.groups_outlined)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _rows.length,
                            itemBuilder: (context, i) => _rowCard(_rows[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _rowCard(WfhMonthlyRow r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _metric('Office', '${r.officeDays} d', '${r.officeHours.toStringAsFixed(1)} h', AppColors.primaryDark),
                _metric('WFH', '${r.wfhDays} d', '${r.wfhHours.toStringAsFixed(1)} h', AppColors.info),
                _metric('Leave', '${r.leaveDays} d', '', AppColors.onLeave),
                _metric('Planned WFH', '${r.approvedWfhDays} d', r.pendingRequests > 0 ? '${r.pendingRequests} pending' : '', AppColors.warning),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: r.totalDays == 0 ? 0 : r.wfhShare, minHeight: 6, backgroundColor: AppColors.primarySoft, color: AppColors.info),
            ),
            const SizedBox(height: 4),
            Text(r.totalDays == 0 ? 'No attendance yet this month' : '${(r.wfhShare * 100).round()}% of working days from home',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, String sub, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Auto-reminder times and the optional monthly limit (WfhSettings on the server).
class _WfhSettingsSheet extends StatefulWidget {
  const _WfhSettingsSheet();

  @override
  State<_WfhSettingsSheet> createState() => _WfhSettingsSheetState();
}

class _WfhSettingsSheetState extends State<_WfhSettingsSheet> {
  final _service = WfhService();
  bool _loading = true;
  bool _saving = false;
  bool _auto = true;
  TimeOfDay _start = const TimeOfDay(hour: 11, minute: 30);
  TimeOfDay _end = const TimeOfDay(hour: 20, minute: 0);
  final _cap = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  TimeOfDay _parse(String hhmm, TimeOfDay fallback) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? fallback.hour, minute: int.tryParse(parts[1]) ?? fallback.minute);
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    try {
      final s = await _service.getSettings();
      if (!mounted) return;
      setState(() {
        if (s != null) {
          _auto = s.autoRemindersEnabled;
          _start = _parse(s.startReminderTime, _start);
          _end = _parse(s.endReminderTime, _end);
          _cap.text = s.maxDaysPerMonth?.toString() ?? '';
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showSnack(context, e.toString(), isError: true);
      }
    }
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked != null) setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cap = int.tryParse(_cap.text.trim());
      await _service.saveSettings(autoRemindersEnabled: _auto, startTime: _fmt(_start), endTime: _fmt(_end), maxDaysPerMonth: cap);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Settings saved.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: _loading
          ? const SizedBox(height: 160, child: LoadingView())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Reminders & limits', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _auto,
                  onChanged: (v) => setState(() => _auto = v),
                  title: const Text('Automatic reminders on WFH days'),
                  subtitle: const Text('Start-of-day and end-of-day nudges to the employee', style: TextStyle(fontSize: 12)),
                ),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: _auto ? () => _pick(true) : null, child: Text('Start by ${_start.format(context)}'))),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton(onPressed: _auto ? () => _pick(false) : null, child: Text('End at ${_end.format(context)}'))),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _cap,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monthly WFH limit per employee (days)', helperText: 'Leave empty for no limit'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save')),
              ],
            ),
    );
  }
}
