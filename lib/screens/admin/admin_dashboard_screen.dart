import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/home_models.dart';
import '../../services/home_service.dart';
import '../../services/leave_service.dart';
import '../../services/notification_service.dart';
import '../../services/overtime_service.dart';
import '../../services/reimbursement_service.dart';
import '../../services/wfh_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/company_updates_card.dart';
import '../../widgets/home_widgets.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/login_screen.dart';
import '../employee/company_updates_screen.dart';
import '../employee/employee_shell.dart';
import '../employee/notifications_screen.dart';
import 'admin_profile_screen.dart';
import 'approvals_screen.dart';
import 'employee_login_activity_screen.dart';
import 'employees_screen.dart';
import 'live_tracking_screen.dart';
import 'password_requests_screen.dart';
import 'payroll_screen.dart';
import 'task_assignment_screen.dart';
import 'team_attendance_screen.dart';
import 'visit_assignment_screen.dart';
import 'wfh_admin_screen.dart';

// Status colours for the ring / legend. Light tones, because they sit on the orange hero (the dark navy hero
// of the first mockup did not match the rest of the app).
const _ringPresent = Color(0xFF86EFAC);
const _ringWfh = Color(0xFF93C5FD);
const _ringLeave = Color(0xFFDDD6FE);
const _ringNotIn = Color(0xFF7C2D12);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _homeService = HomeService();
  final _notificationService = AppNotificationService();
  final _updatesApi = CompanyUpdatesApi();

  AdminHome? _home;
  List<CompanyUpdate> _updates = [];
  int _unreadNotifications = 0;
  bool _loading = true;
  bool _reminding = false;
  String? _error;

  // Approvals acted on from this screen are removed from the list straight away (and counted down) without
  // waiting for a reload.
  final Set<String> _doneApprovals = {};
  final Set<String> _busyApprovals = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _home == null;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([_homeService.getAdminHome(), _notificationService.getUnreadCount()]);
      if (!mounted) return;
      setState(() {
        _home = results[0] as AdminHome;
        _unreadNotifications = results[1] as int;
        _doneApprovals.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
    _loadUpdates();
  }

  Future<void> _loadUpdates() async {
    try {
      final feed = await _updatesApi.getFeed();
      if (mounted) setState(() => _updates = feed);
    } catch (_) {
      // optional card - the rest of the dashboard does not depend on it
    }
  }

  Future<void> _logout() async {
    await context.read<Session>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => mounted ? _load() : null);
  }

  Future<void> _remindAll() async {
    setState(() => _reminding = true);
    try {
      final r = await _homeService.remindNotCheckedIn();
      if (!mounted) return;
      final msg = r.sent > 0
          ? 'Reminder sent to ${r.sent} ${r.sent == 1 ? 'person' : 'people'}.${r.skipped > 0 ? ' ${r.skipped} already reminded in the last hour.' : ''}'
          : (r.skipped > 0 ? 'Everyone was already reminded in the last hour.' : 'Nobody to remind right now.');
      showSnack(context, msg);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not reach the server.', isError: true);
    } finally {
      if (mounted) setState(() => _reminding = false);
    }
  }

  String _key(PendingApproval a) => '${a.kind}:${a.refId}';

  Future<void> _decide(PendingApproval a, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (reason == null) return; // cancelled
    }
    final status = approve ? 'Approved' : 'Rejected';
    setState(() => _busyApprovals.add(_key(a)));
    try {
      switch (a.kind) {
        case 'Leave':
          approve ? await LeaveService().approveLeave(a.refId) : await LeaveService().rejectLeave(a.refId);
          break;
        case 'WFH':
          await WfhService().action(a.refId, status, remarks: reason);
          break;
        case 'Reimbursement':
          await ReimbursementService().actionReimbursement(a.refId, status, remarks: reason);
          break;
        default:
          await OvertimeService().actionOvertimeLog(a.refId, status, remarks: reason);
      }
      if (!mounted) return;
      setState(() => _doneApprovals.add(_key(a)));
      showSnack(context, approve ? 'Approved.' : 'Rejected.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not reach the server.', isError: true);
    } finally {
      if (mounted) setState(() => _busyApprovals.remove(_key(a)));
    }
  }

  Future<String?> _askReason() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this request?'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Reason (shown to the employee)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Reject', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      body: _loading
          ? const LoadingView()
          : _error != null && _home == null
              ? SafeArea(child: ErrorView(message: _error!, onRetry: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _heroWithChips(session),
                      const SizedBox(height: 56),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _alert(),
                            _quickActions(),
                            CompanyUpdatesCard(updates: _updates, onViewAll: () => _open(const CompanyUpdatesScreen())),
                            const SizedBox(height: 14),
                            _teamToday(),
                            _approvalsCard(),
                            _weekCard(),
                            _tasksCard(),
                            _payrollCard(),
                            const SizedBox(height: 70),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ---------------- hero: ring + legend + chips ----------------

  Widget _heroWithChips(Session session) {
    final h = _home;
    final s = h?.summary;
    final top = MediaQuery.of(context).padding.top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(18, top + 14, 18, 62),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _open(const AdminProfileScreen()),
                    child: SessionAvatar(name: session.userName, radius: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(session.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  // Bell: the same white rounded box as on the employee Home screen.
                  InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      if (mounted) _load();
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
                      child: Center(
                        child: Badge(
                          isLabelVisible: _unreadNotifications > 0,
                          label: Text('$_unreadNotifications'),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (v) {
                      if (v == 'profile') {
                        _open(const AdminProfileScreen());
                      } else if (v == 'employee') {
                        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const EmployeeShell()), (r) => false);
                      } else if (v == 'logout') {
                        _logout();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'profile', child: Text('My Profile')),
                      if (session.employeeId != 0) const PopupMenuItem(value: 'employee', child: Text('Switch to Employee view')),
                      const PopupMenuItem(value: 'logout', child: Text('Logout')),
                    ],
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.border)),
                      child: const Icon(Icons.more_vert),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (s == null)
                const Text('Attendance figures are not available right now.', style: TextStyle(color: Colors.white70, fontSize: 13))
              else
                Row(
                  children: [
                    _ring(s),
                    const SizedBox(width: 22),
                    Expanded(child: _legend(s)),
                  ],
                ),
            ],
          ),
        ),
        Positioned(left: 16, right: 16, bottom: -44, child: _chips(h)),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _ring(TodaySummary s) {
    final total = s.totalExpected;
    final segs = <(double, Color)>[
      if (total > 0) (s.present / total, _ringPresent),
      if (total > 0) (s.wfh / total, _ringWfh),
      if (total > 0) (s.leave / total, _ringLeave),
      if (total > 0) (s.notCheckedIn / total, _ringNotIn),
    ];
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(116, 116), painter: _RingPainter(segs)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.isWorkingDay) ...[
                Text('${s.punchedIn}/$total', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const Text('present', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ] else ...[
                const Icon(Icons.beach_access_outlined, color: Colors.white, size: 26),
                Text(s.todayType == 'Holiday' ? 'Holiday' : 'Weekly off', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(TodaySummary s) {
    Widget row(Color c, String label, int n) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13))),
              Text('$n', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        );
    if (!s.isWorkingDay) {
      return Text(
        s.todayType == 'Holiday' ? 'Office is closed today${(s.holidayTitle ?? '').isEmpty ? '' : ': ${s.holidayTitle}'}.' : 'Today is a weekly off.',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      );
    }
    return Column(
      children: [
        row(_ringPresent, 'Present', s.present),
        row(_ringWfh, 'On WFH', s.wfh),
        row(_ringLeave, 'On leave', s.leave),
        row(_ringNotIn, 'Not checked in', s.notCheckedIn),
      ],
    );
  }

  Widget _chips(AdminHome? h) {
    Widget chip(String value, String label, VoidCallback onTap, {bool hot = false}) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: hot ? AppColors.primary : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          chip('${h?.leavePending ?? 0}', 'Leave', () => _open(const ApprovalsScreen())),
          chip('${h?.reimbursementPending ?? 0}', 'Reimb.', () => _open(const ApprovalsScreen(initialTabIndex: 1))),
          chip('${h?.wfhPending ?? 0}', 'WFH', () => _open(const ApprovalsScreen(initialTabIndex: 3))),
          chip('${h?.tasksDue ?? 0}', 'Tasks due', () => _open(const TaskAssignmentScreen()), hot: (h?.tasksDue ?? 0) > 0),
        ],
      ),
    );
  }

  // ---------------- alert ----------------

  Widget _alert() {
    final h = _home;
    final s = h?.summary;
    if (h == null || s == null || !s.isWorkingDay) return const SizedBox.shrink();
    final n = h.canStillPunch;
    if (n == 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), border: Border.all(color: AppColors.success.withValues(alpha: 0.35)), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Everyone who can check in has checked in', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('${s.punchedIn} of ${s.totalExpected} expected today', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.alarm, color: AppColors.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$n ${n == 1 ? "employee hasn't" : "employees haven't"} checked in", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(
                  s.late > 0 ? '${s.late} late today (office starts at ${s.officeStart})' : 'Office starts at ${s.officeStart}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _reminding ? null : _remindAll,
            child: _reminding
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Remind all', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ---------------- quick actions ----------------

  Widget _quickActions() {
    return HomeCard(
      title: 'Quick actions',
      child: QuickActionGrid(items: [
        QuickActionItem('Attendance', Icons.fingerprint, AppColors.info, () => _open(const TeamAttendanceScreen())),
        QuickActionItem('Approvals', Icons.fact_check_outlined, AppColors.primary, () => _open(const ApprovalsScreen())),
        QuickActionItem('Assign task', Icons.playlist_add_check_outlined, AppColors.success, () => _open(const TaskAssignmentScreen())),
        QuickActionItem('Field visits', Icons.map_outlined, const Color(0xFF4F46E5), () => _open(const VisitAssignmentScreen())),
        QuickActionItem('Live tracking', Icons.navigation_outlined, AppColors.warning, () => _open(const LiveTrackingScreen())),
        QuickActionItem('Work from home', Icons.home_work_outlined, AppColors.info, () => _open(const WfhAdminScreen())),
        QuickActionItem('Login activity', Icons.admin_panel_settings_outlined, AppColors.danger, () => _open(const EmployeeLoginActivityScreen())),
        QuickActionItem('Payroll', Icons.payments_outlined, const Color(0xFF9333EA), () => _open(const PayrollScreen())),
        QuickActionItem('Employees', Icons.groups_outlined, const Color(0xFF0D9488), () => _open(const EmployeesScreen())),
        QuickActionItem('Post update', Icons.campaign_outlined, AppColors.warning, () => _open(const CompanyUpdatesScreen())),
        QuickActionItem('Password requests', Icons.lock_reset_outlined, AppColors.danger, () => _open(const PasswordRequestsScreen())),
      ]),
    );
  }

  // ---------------- team today ----------------

  Widget _teamToday() {
    final board = _home?.board ?? const <TeamMemberToday>[];
    return HomeCard(
      title: 'Team today',
      action: 'View all',
      onAction: () => _open(const TeamAttendanceScreen()),
      child: board.isEmpty
          ? const Text('No team data available.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          : Column(
              children: [
                for (var i = 0; i < board.length && i < 6; i++)
                  HomeListRow(
                    divider: i > 0,
                    leading: InitialsAvatar(board[i].initials, board[i].color),
                    title: board[i].name,
                    subtitle: board[i].subtitle,
                    trailing: HomePill(board[i].statusLabel, board[i].color),
                  ),
                if (board.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('+ ${board.length - 6} more', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
    );
  }

  // ---------------- approvals ----------------

  Widget _approvalsCard() {
    final h = _home;
    final items = (h?.approvals ?? const <PendingApproval>[]).where((a) => !_doneApprovals.contains(_key(a))).toList();
    final total = math.max(0, (h?.totalPending ?? 0) - _doneApprovals.length);
    return HomeCard(
      title: 'Needs your approval',
      action: 'See all',
      onAction: () => _open(const ApprovalsScreen()),
      trailing: total > 0
          ? Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: Text('$total', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            )
          : null,
      child: items.isEmpty
          ? Text(total > 0 ? 'More requests are waiting on the Approvals page.' : 'All caught up - nothing waiting for you.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  HomeListRow(
                    divider: i > 0,
                    leading: IconBox(items[i].icon, items[i].color),
                    title: items[i].amount == null ? items[i].title : '${items[i].title} · ₹${items[i].amount!.toStringAsFixed(items[i].amount! == items[i].amount!.roundToDouble() ? 0 : 2)}',
                    subtitle: items[i].subtitle,
                    trailing: _busyApprovals.contains(_key(items[i]))
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _roundBtn(Icons.check, AppColors.success, () => _decide(items[i], true)),
                              const SizedBox(width: 6),
                              _roundBtn(Icons.close, AppColors.danger, () => _decide(items[i], false)),
                            ],
                          ),
                  ),
              ],
            ),
    );
  }

  Widget _roundBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  // ---------------- week bars ----------------

  Widget _weekCard() {
    final week = _home?.week ?? const <WeekDayCount>[];
    return HomeCard(
      title: 'Attendance this week',
      child: week.isEmpty
          ? const Text('No data.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          : SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in week)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(d.isOff && d.present == 0 ? '-' : '${d.present}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: math.max(0.04, d.total == 0 ? 0.04 : d.present / d.total),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: d.isToday ? AppColors.primary : (d.isOff ? AppColors.border : AppColors.primary.withValues(alpha: 0.3)),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(d.isToday ? 'Today' : d.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ---------------- open tasks ----------------

  Widget _tasksCard() {
    final tasks = _home?.dueTasks ?? const <DueTask>[];
    return HomeCard(
      title: 'Open tasks',
      action: 'View all',
      onAction: () => _open(const TaskAssignmentScreen()),
      child: tasks.isEmpty
          ? const Text('No open tasks.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          : Column(
              children: [
                for (var i = 0; i < tasks.length; i++)
                  HomeListRow(
                    divider: i > 0,
                    leading: const IconBox(Icons.assignment_outlined, AppColors.info),
                    title: tasks[i].title,
                    subtitle: _taskSubtitle(tasks[i]),
                    trailing: _taskPill(tasks[i]),
                  ),
              ],
            ),
    );
  }

  String _taskSubtitle(DueTask t) {
    final d = t.daysToDue;
    final due = d == null
        ? 'No due date'
        : d < 0
            ? 'Was due ${DateFormat('d MMM').format(t.dueDate!)}'
            : d == 0
                ? 'Due today'
                : 'Due ${DateFormat('d MMM').format(t.dueDate!)}';
    return t.assignedTo.isEmpty ? due : '$due · ${t.assignedTo}';
  }

  Widget _taskPill(DueTask t) {
    final d = t.daysToDue;
    if (d != null && d < 0) return HomePill('Overdue ${-d}d', AppColors.danger);
    if (d == 0) return const HomePill('Due today', AppColors.warning);
    return HomePill(t.status.isEmpty ? 'Open' : t.status, AppColors.info);
  }

  // ---------------- payroll ----------------

  Widget _payrollCard() {
    final p = _home?.payroll;
    return HomeCard(
      title: p == null ? 'Payroll' : 'Payroll · ${p.monthName}',
      action: 'Details',
      onAction: () => _open(const PayrollScreen()),
      child: p == null
          ? const Text('Payroll figures are not available right now.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _payTile('${p.pending}', 'Salaries pending')),
                    const SizedBox(width: 10),
                    Expanded(child: _payTile(p.monthEnd, 'Month end · ${p.daysLeft} days left')),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Run status: ${(p.runStatus ?? '').isEmpty ? 'Not started' : p.runStatus} · ${p.paid} of ${p.active} paid', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _open(const PayrollScreen()),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('Review and process payroll', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _payTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Donut chart: a faint full circle with one coloured arc per status, drawn clockwise from the top.
class _RingPainter extends CustomPainter {
  _RingPainter(this.segments);
  final List<(double, Color)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawArc(rect, 0, 2 * math.pi, false, base);

    var start = -math.pi / 2;
    for (final (fraction, color) in segments) {
      if (fraction <= 0) continue;
      final sweep = 2 * math.pi * fraction;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = color;
      // a hair of gap between neighbouring segments so they read as separate
      canvas.drawArc(rect, start, math.max(0.0, sweep - 0.03), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.segments != segments;
}
