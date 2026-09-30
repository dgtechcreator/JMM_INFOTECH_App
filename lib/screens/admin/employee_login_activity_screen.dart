import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../services/admin_service.dart';
import '../../services/login_activity_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Admin "Employee Login Activity": pick an employee and see every phone/browser their account signed in
/// from, when and from which IP (including failed attempts) — plus the punch-device audit that catches one
/// person punching in for another from their own phone, and the list of phones used by more than one
/// account. Web twin: Views/LoginActivity/Index.cshtml.
class EmployeeLoginActivityScreen extends StatefulWidget {
  const EmployeeLoginActivityScreen({super.key, this.employeeId, this.employeeName});

  /// Pre-select an employee (e.g. opened from their profile).
  final int? employeeId;
  final String? employeeName;

  @override
  State<EmployeeLoginActivityScreen> createState() => _EmployeeLoginActivityScreenState();
}

class _EmployeeLoginActivityScreenState extends State<EmployeeLoginActivityScreen> with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  final _service = LoginActivityService();
  late final TabController _tabController;

  List<({int id, String name})> _employees = [];
  int? _selectedId;

  // Activity tab
  EmployeeLoginActivity? _activity;
  bool _activityLoading = false;
  String? _activityError;

  // Punch audit tab
  List<PunchAuditRow> _audit = [];
  bool _auditLoading = true;
  String? _auditError;
  bool _onlyAlerts = false;

  // Shared devices tab
  List<SharedDeviceRow> _shared = [];
  bool _sharedLoading = true;
  String? _sharedError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedId = widget.employeeId;
    _loadEmployees();
    if (_selectedId != null) _loadActivity();
    _loadAudit();
    _loadShared();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final rows = await _adminService.getEmployeeList();
      final list = <({int id, String name})>[];
      for (final e in rows) {
        final id = int.tryParse('${e['ID']}') ?? 0;
        final name = '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim();
        if (id != 0 && name.isNotEmpty) list.add((id: id, name: name));
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _employees = list);
    } catch (_) {}
  }

  Future<void> _loadActivity() async {
    final id = _selectedId;
    if (id == null) return;
    setState(() {
      _activityLoading = true;
      _activityError = null;
    });
    try {
      final a = await _service.getEmployeeLoginActivity(id);
      if (mounted) setState(() { _activity = a; _activityLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _activityError = e.toString(); _activityLoading = false; });
    }
  }

  Future<void> _loadAudit() async {
    setState(() {
      _auditLoading = true;
      _auditError = null;
    });
    try {
      final now = DateTime.now();
      final rows = await _service.getPunchDeviceAudit(from: now.subtract(const Duration(days: 30)), to: now, employeeId: _selectedId);
      if (mounted) setState(() { _audit = rows; _auditLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _auditError = e.toString(); _auditLoading = false; });
    }
  }

  Future<void> _loadShared() async {
    setState(() {
      _sharedLoading = true;
      _sharedError = null;
    });
    try {
      final rows = await _service.getSharedDeviceReport();
      if (mounted) setState(() { _shared = rows; _sharedLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _sharedError = e.toString(); _sharedLoading = false; });
    }
  }

  void _select(int? id) {
    setState(() {
      _selectedId = id;
      _activity = null;
    });
    if (id != null) _loadActivity();
    _loadAudit();
  }

  String get _selectedName {
    if (_selectedId == null) return '';
    for (final e in _employees) {
      if (e.id == _selectedId) return e.name;
    }
    return widget.employeeName ?? 'this employee';
  }

  Future<void> _forceLogout() async {
    final id = _selectedId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log $_selectedName out everywhere?'),
        content: const Text('Every phone signed in to this account is signed out immediately and the employee is notified. Use it for a lost phone or suspected misuse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out everywhere', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final count = await _service.forceLogoutEmployee(id);
      if (mounted) showSnack(context, '$count session${count == 1 ? '' : 's'} signed out.');
      _loadActivity();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Activity'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Employee'), Tab(text: 'Punch audit'), Tab(text: 'Shared phones')]),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<int?>(
              initialValue: _selectedId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Employee', prefixIcon: Icon(Icons.person_search_outlined)),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All employees', overflow: TextOverflow.ellipsis)),
                ..._employees.map((e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: _select,
            ),
          ),
          Expanded(
            child: TabBarView(controller: _tabController, children: [_activityTab(), _auditTab(), _sharedTab()]),
          ),
        ],
      ),
    );
  }

  // ---------------- tabs ----------------

  Widget _activityTab() {
    if (_selectedId == null) {
      return const EmptyState(message: 'Choose an employee above to see where their account is signed in.', icon: Icons.manage_search_outlined);
    }
    if (_activityLoading) return const LoadingView();
    if (_activityError != null) return ErrorView(message: _activityError!, onRetry: _loadActivity);
    final a = _activity;
    if (a == null) return const SizedBox.shrink();
    if (a.message != null && a.items.isEmpty) return EmptyState(message: a.message!, icon: Icons.person_off_outlined);

    return RefreshIndicator(
      onRefresh: _loadActivity,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (a.summary != null) ...[
            Row(
              children: [
                Expanded(child: StatCard(label: 'Signed in now', value: '${a.summary!.activeSessions}', color: AppColors.success, icon: Icons.smartphone)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(label: 'Devices (30 d)', value: '${a.summary!.devices30d}', color: AppColors.info, icon: Icons.devices_other_outlined)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: StatCard(label: 'Failed (7 d)', value: '${a.summary!.failedAttempts7d}', color: a.summary!.failedAttempts7d > 0 ? AppColors.danger : AppColors.textSecondary, icon: Icons.gpp_bad_outlined)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(label: 'Shared phones', value: '${a.summary!.sharedDevices30d}', color: a.summary!.sharedDevices30d > 0 ? AppColors.warning : AppColors.textSecondary, icon: Icons.people_alt_outlined)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _forceLogout,
            icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
            label: const Text('Log out everywhere', style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Sign-ins and security events'),
          if (a.items.isEmpty)
            const EmptyState(message: 'No activity recorded yet.', icon: Icons.history)
          else
            ...a.items.map(_activityTile),
        ],
      ),
    );
  }

  Widget _activityTile(LoginActivityItem it) {
    final IconData icon;
    final Color color;
    if (it.isFailedAttempt) {
      icon = Icons.gpp_bad_outlined;
      color = AppColors.danger;
    } else if (it.isEvent) {
      icon = Icons.shield_outlined;
      color = AppColors.warning;
    } else if (it.source == 'Web') {
      icon = Icons.desktop_windows_outlined;
      color = AppColors.info;
    } else {
      icon = Icons.smartphone;
      color = it.status == 'Active' ? AppColors.success : AppColors.textSecondary;
    }
    final lines = <String>[
      if (it.deviceName.isNotEmpty) it.deviceName,
      if (it.osVersion.isNotEmpty) it.osVersion,
      if (it.appVersion.isNotEmpty) 'app ${it.appVersion}',
      if (it.ipAddress.isNotEmpty) 'IP ${it.ipAddress}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: it.sharedCount > 0 ? const Color(0xFFFFFBEB) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                      if (!it.isEvent) StatusBadge(status: it.status),
                    ],
                  ),
                  Text(formatDateTime(it.eventOn), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (lines.isNotEmpty) Text(lines.join(' · '), style: const TextStyle(fontSize: 12)),
                  if (it.details != null && it.details!.isNotEmpty) Text(it.details!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (it.logoutOn != null) Text('Ended ${formatDateTime(it.logoutOn)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  if (it.sharedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Also used by: ${it.sharedWith ?? '${it.sharedCount} other account(s)'}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _auditTab() {
    if (_auditLoading) return const LoadingView();
    if (_auditError != null) return ErrorView(message: _auditError!, onRetry: _loadAudit);
    final rows = _onlyAlerts ? _audit.where((r) => r.alertLevel.isNotEmpty).toList() : _audit;

    return Column(
      children: [
        SwitchListTile(
          value: _onlyAlerts,
          onChanged: (v) => setState(() => _onlyAlerts = v),
          title: const Text('Only show alerts', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Last 30 days · punches with device info', style: TextStyle(fontSize: 11)),
          dense: true,
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(message: _onlyAlerts ? 'No alerts in the last 30 days.' : 'No punches with device information yet.\n(Only punches made after this feature went live are recorded.)', icon: Icons.verified_user_outlined)
              : RefreshIndicator(
                  onRefresh: _loadAudit,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _auditTile(rows[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _auditTile(PunchAuditRow r) {
    final warn = r.alertLevel == 'warn';
    final info = r.alertLevel == 'info';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: warn ? const Color(0xFFFEF2F2) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (r.workMode == 'WFH')
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Text('WFH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.info)),
                  ),
                Text(formatDate(r.attendanceDate), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 4),
            Text('In ${formatTime(r.punchInTime)} · ${r.inDevice}', style: const TextStyle(fontSize: 12)),
            Text('Out ${formatTime(r.punchOutTime)} · ${r.outDevice}', style: const TextStyle(fontSize: 12)),
            if (r.alertText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(warn ? Icons.warning_amber_rounded : Icons.info_outline, size: 16, color: warn ? AppColors.danger : (info ? AppColors.info : AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(r.alertText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: warn ? AppColors.danger : AppColors.info))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sharedTab() {
    if (_sharedLoading) return const LoadingView();
    if (_sharedError != null) return ErrorView(message: _sharedError!, onRetry: _loadShared);
    if (_shared.isEmpty) {
      return const EmptyState(message: 'No phone has been used by more than one account in the last 30 days.', icon: Icons.phonelink_lock_outlined);
    }
    return RefreshIndicator(
      onRefresh: _loadShared,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _shared.length,
        itemBuilder: (context, i) {
          final d = _shared[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.smartphone, color: AppColors.warning),
              title: Text(d.deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${d.userCount} accounts: ${d.users}\nLast seen ${formatDateTime(d.lastSeen)}'),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
