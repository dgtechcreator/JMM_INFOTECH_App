import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/date_format.dart';
import '../../core/location_helper.dart';
import '../../core/session.dart';
import '../../models/home_models.dart';
import '../../models/models.dart';
import '../../services/attendance_service.dart';
import '../../services/home_service.dart';
import '../../services/notification_service.dart';
import '../../services/task_service.dart';
import '../../services/wfh_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/company_updates_card.dart';
import '../../widgets/home_widgets.dart';
import '../../widgets/missed_punchout_card.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/swipe_button.dart';
import '../../widgets/wfh_day_card.dart';
import 'company_updates_screen.dart';
import 'daily_log_screen.dart';
import 'documents_screen.dart';
import 'leave_screen.dart';
import 'my_visits_screen.dart';
import 'notifications_screen.dart';
import 'overtime_screen.dart';
import 'reimbursement_screen.dart';
import 'salary_screen.dart';
import 'tasks_screen.dart';
import 'wfh_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _attendanceService = AttendanceService();
  final _taskService = TaskService();
  final _notificationService = AppNotificationService();
  final _wfhService = WfhService();
  final _homeService = HomeService();
  final _updatesApi = CompanyUpdatesApi();

  AttendanceRecord? _today;
  // Today's APPROVED Work From Home day, if any. Loaded leniently: an older server without the WFH endpoints
  // (or a hiccup) must never break the rest of the Home screen, so failures simply mean "no WFH today".
  WfhToday? _wfhToday;
  // On an approved WFH day the WFH card replaces the office punch card — unless the employee says they're
  // going to the office after all.
  bool _useOfficePunch = false;
  List<TaskItem> _tasks = [];
  int _unreadNotifications = 0;
  bool _loading = true;
  bool _punchBusy = false;
  int _swipeReset = 0; // bumped when a punch-out is cancelled, so the slider snaps back to the start
  int _missedToken = 0; // bumped on every reload so the "forgot to punch out" card re-checks too
  String? _error;

  // Everything below is loaded leniently too: a server that does not have the newer endpoints yet (old build,
  // migration not run) just leaves these cards empty instead of failing the whole screen.
  List<CompanyUpdate> _updates = [];
  bool _updatesLoading = true;
  MonthCalendar? _calendar;
  late DateTime _calMonth;
  List<LeaveBalanceItem> _leaveBalance = [];
  MonthSummary? _summary; // current month's summary - carries the standard hours + office hours for the hero

  // Ticks while the employee is punched in, so the Working Hours card counts up live instead of staying at the
  // last value the server returned (0h 00m right after punching in).
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calMonth = DateTime(now.year, now.month);
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _isLive) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Punched in today and not punched out yet.
  bool get _isLive => _today?.punchInTime != null && _today?.punchOutTime == null;

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _calMonth.year == n.year && _calMonth.month == n.month;
  }

  int _workedMinutesNow() {
    final today = _today;
    if (today == null) return 0;
    return liveWorkedMinutes(punchIn: today.punchInTime, punchOut: today.punchOutTime, serverMinutes: today.workedMinutes);
  }

  Future<T?> _lenient<T>(Future<T> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _attendanceService.getTodayStatus(),
        _taskService.getMyTasks(),
        _notificationService.getUnreadCount(),
        _lenient<WfhToday?>(_wfhService.getToday()),
      ]);
      if (!mounted) return;
      setState(() {
        _today = results[0] as AttendanceRecord?;
        _tasks = results[1] as List<TaskItem>;
        _unreadNotifications = results[2] as int;
        _wfhToday = results[3] as WfhToday?;
        _missedToken++;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
    // The extra cards fill in after the main content is already on screen.
    _loadUpdates();
    _loadCalendar();
    _loadLeaveBalance();
  }

  Future<void> _loadUpdates() async {
    final feed = await _lenient(_updatesApi.getFeed());
    if (!mounted) return;
    setState(() {
      _updates = feed ?? _updates;
      _updatesLoading = false;
    });
  }

  Future<void> _loadCalendar() async {
    final cal = await _lenient(_homeService.getHomeCalendar(month: _calMonth.month, year: _calMonth.year));
    if (!mounted || cal == null) return;
    setState(() {
      _calendar = cal;
      if (_isCurrentMonth && cal.summary != null) _summary = cal.summary;
    });
  }

  Future<void> _loadLeaveBalance() async {
    final lb = await _lenient(_homeService.getLeaveBalance());
    if (!mounted || lb == null) return;
    setState(() => _leaveBalance = lb);
  }

  Future<void> _moveMonth(int delta) async {
    setState(() => _calMonth = DateTime(_calMonth.year, _calMonth.month + delta));
    await _loadCalendar();
  }

  Future<void> _punch(bool isPunchIn) async {
    if (_punchBusy) return;
    if (!isPunchIn) {
      // Punch out is final - ask first. (The server also refuses a punch out within a few minutes of punching in.)
      final sure = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Punch out?'),
          content: const Text('Please confirm you are done for the day. You cannot undo this yourself.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not yet')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, punch out')),
          ],
        ),
      );
      if (sure != true || !mounted) {
        // Cancelled: put the slider back at the start.
        if (mounted) setState(() => _swipeReset++);
        return;
      }
    }
    setState(() => _punchBusy = true);
    try {
      final (lat, lng) = await LocationHelper.tryGetLatLng();
      final result = isPunchIn
          ? await _attendanceService.punchIn(lat: lat, lng: lng)
          : await _attendanceService.punchOut(lat: lat, lng: lng);
      final message = result['message']?.toString() ?? '';
      if (message == 'success') {
        if (mounted) showSnack(context, isPunchIn ? 'Punched in!' : 'Punched out!');
        await _load();
      } else if (mounted) {
        showSnack(context, message.isEmpty ? 'Something went wrong.' : message, isError: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Network error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _punchBusy = false);
    }
  }

  void _open(Widget screen, {bool reload = false}) {
    final f = Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (reload) f.then((_) => mounted ? _load() : null);
  }

  Future<void> _openUpdates() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyUpdatesScreen()));
    if (mounted) _loadUpdates(); // the unread "N new" badge changes once they have been seen
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const LoadingView()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _header(session),
                    const SizedBox(height: 16),
                    if (_error != null) ErrorView(message: _error!, onRetry: _load),
                    MissedPunchOutCard(refreshToken: _missedToken, onChanged: _load),
                    if (_showWfhCard) ...[
                      WfhDayCard(today: _wfhToday!, onChanged: _load),
                      if (_wfhToday!.notStarted)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() => _useOfficePunch = true),
                            child: const Text("I'm at the office today — use office punch"),
                          ),
                        ),
                    ] else
                      _buildHero(),
                    const SizedBox(height: 14),
                    CompanyUpdatesCard(updates: _updates, loading: _updatesLoading, onViewAll: _openUpdates),
                    const SizedBox(height: 14),
                    _statsRow(),
                    const SizedBox(height: 14),
                    _quickActions(),
                    _tasksCard(),
                    _leaveBalanceCard(),
                    _calendarCard(),
                  ],
                ),
        ),
      ),
    );
  }

  // The WFH card is shown whenever there's an approved WFH day today that hasn't been overridden by an office
  // punch (PunchedInOffice) or the employee choosing the office.
  bool get _showWfhCard => _wfhToday != null && !_wfhToday!.punchedInOffice && !_useOfficePunch;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _header(Session session) {
    return Row(
      children: [
        SessionAvatar(name: session.userName, radius: 23),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(session.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(13),
          // HomeScreen is kept alive inside EmployeeShell's IndexedStack, so it never re-runs initState
          // when the user comes back from the bell — without awaiting this push and reloading, the
          // unread badge would keep showing the pre-visit count even after the user reads/marks
          // everything as read on NotificationsScreen.
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
      ],
    );
  }

  // ---------------- hero ----------------

  Widget _buildHero() {
    final hasPunchedIn = _today?.punchInTime != null;
    final hasPunchedOut = _today?.punchOutTime != null;
    final complete = hasPunchedIn && hasPunchedOut;
    final std = _summary?.standardHours ?? 8;
    final minutes = _workedMinutesNow();
    final progress = std <= 0 ? 0.0 : (minutes / (std * 60)).clamp(0.0, 1.0);
    final stdText = std == std.roundToDouble() ? std.toInt().toString() : std.toStringAsFixed(1);
    final lockLeft = _today?.punchOutLockRemaining ?? Duration.zero;
    final punchOutLocked = hasPunchedIn && !hasPunchedOut && lockLeft > Duration.zero;

    String statusText;
    if (!hasPunchedIn) {
      statusText = 'Not punched in';
    } else if (!hasPunchedOut) {
      statusText = (_today?.isWfh ?? false) ? 'Working from home' : 'Working';
    } else {
      statusText = (_today?.statusId == 'HalfDay') ? 'Half Day' : 'Present';
    }
    final statusColor = !hasPunchedIn
        ? AppColors.warning
        : (!hasPunchedOut ? AppColors.info : (_today?.statusId == 'HalfDay' ? AppColors.warning : AppColors.success));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Working hours', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(DateFormat('EEE, d MMM y').format(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: _formatWorkedHours(minutes), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1)),
                TextSpan(text: '  of ${stdText}h', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
              ],
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white.withValues(alpha: 0.25), valueColor: const AlwaysStoppedAnimation(Colors.white)),
          ),
          const SizedBox(height: 8),
          Text(
            _summary != null && _summary!.officeStart.isNotEmpty ? 'Shift ${_summary!.officeStart} - ${_summary!.officeEnd}' : ' ',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _timeBox('Punch in', hasPunchedIn ? formatTime(_today!.punchInTime) : '--')),
              const SizedBox(width: 10),
              Expanded(child: _timeBox('Punch out', hasPunchedOut ? formatTime(_today!.punchOutTime) : '--')),
            ],
          ),
          const SizedBox(height: 16),
          if (complete)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(40)),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: AppColors.success, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Done for today', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
                  _statusChip(statusText, statusColor),
                  const SizedBox(width: 4),
                ],
              ),
            )
          else ...[
            SwipeToConfirmButton(
              key: ValueKey('$hasPunchedIn-$punchOutLocked-$_swipeReset'),
              label: punchOutLocked
                  ? 'Punch out unlocks in ${lockLeft.inMinutes + 1} min'
                  : (hasPunchedIn ? 'Slide to punch out' : 'Slide to punch in'),
              color: Colors.white.withValues(alpha: 0.25),
              busy: _punchBusy,
              // Punch out stays locked for a few minutes after punching in: a slow-network double slide used to
              // punch in AND out together.
              enabled: !punchOutLocked,
              onConfirm: () => _punch(!hasPunchedIn),
            ),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: _statusChip(statusText, statusColor)),
          ],
        ],
      ),
    );
  }

  Widget _timeBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatWorkedHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  // ---------------- stats ----------------

  Widget _statsRow() {
    final s = _calendar?.summary;
    String v(int? n) => n == null ? '-' : '$n';
    return Row(
      children: [
        Expanded(child: HomeStatTile(value: v(s?.presentDays), label: 'Present days', color: AppColors.success)),
        const SizedBox(width: 10),
        Expanded(child: HomeStatTile(value: v(s?.halfDays), label: 'Half days', color: AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(child: HomeStatTile(value: v(s?.absentDays), label: 'Absent days', color: AppColors.danger)),
      ],
    );
  }

  // ---------------- quick actions ----------------

  Widget _quickActions() {
    return HomeCard(
      title: 'Quick actions',
      child: QuickActionGrid(items: [
        QuickActionItem('Reimburse', Icons.receipt_long_outlined, AppColors.info, () => _open(const ReimbursementScreen())),
        QuickActionItem('Daily log', Icons.edit_note_outlined, AppColors.warning, () => _open(const DailyLogScreen())),
        QuickActionItem('Payslip', Icons.account_balance_wallet_outlined, AppColors.success, () => _open(const SalaryScreen())),
        QuickActionItem('My visits', Icons.map_outlined, AppColors.danger, () => _open(const MyVisitsScreen())),
        QuickActionItem('WFH', Icons.home_work_outlined, AppColors.info, () => _open(const WfhScreen(), reload: true)),
        QuickActionItem('Overtime', Icons.timer_outlined, AppColors.holiday, () => _open(const OvertimeScreen())),
        QuickActionItem('Documents', Icons.description_outlined, const Color(0xFF4F46E5), () => _open(const DocumentsScreen())),
        QuickActionItem('Apply leave', Icons.beach_access_outlined, AppColors.warning, () => _open(const LeaveScreen())),
      ]),
    );
  }

  // ---------------- today's tasks ----------------

  DateTime? _parseDue(String s) {
    try {
      return DateFormat('dd MMM yyyy').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  Widget _tasksCard() {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final open = _tasks.where((t) => t.statusId == 1 || t.statusId == 2).map((t) {
      final due = _parseDue(t.dueDate);
      return (task: t, days: due?.difference(midnight).inDays);
    }).toList()
      ..sort((a, b) => (a.days ?? 9999).compareTo(b.days ?? 9999));

    return HomeCard(
      title: "Today's tasks",
      action: 'View all',
      onAction: () => _open(const TasksScreen()),
      child: open.isEmpty
          ? const Text('Nothing pending. You are all caught up!', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          : Column(
              children: [
                for (var i = 0; i < open.length && i < 4; i++)
                  HomeListRow(
                    divider: i > 0,
                    leading: const IconBox(Icons.assignment_outlined, AppColors.info),
                    title: open[i].task.title,
                    subtitle: _taskSubtitle(open[i].task, open[i].days),
                    trailing: _taskPill(open[i].task, open[i].days),
                  ),
              ],
            ),
    );
  }

  String _taskSubtitle(TaskItem t, int? days) {
    final due = days == null
        ? 'No due date'
        : days < 0
            ? 'Was due ${t.dueDate}'
            : days == 0
                ? 'Due today'
                : days == 1
                    ? 'Due tomorrow'
                    : 'Due ${t.dueDate}';
    return t.projectName.isEmpty ? due : '$due · ${t.projectName}';
  }

  Widget _taskPill(TaskItem t, int? days) {
    if (days != null && days < 0) return const HomePill('Overdue', AppColors.danger);
    if (days == 0) return const HomePill('Due today', AppColors.warning);
    if (days == 1) return const HomePill('Due tomorrow', AppColors.warning);
    return HomePill(t.status.isEmpty ? 'Pending' : t.status, AppColors.info);
  }

  // ---------------- leave balance ----------------

  Widget _leaveBalanceCard() {
    return HomeCard(
      title: 'Leave balance',
      action: 'Apply',
      onAction: () => _open(const LeaveScreen()),
      child: _leaveBalance.isEmpty
          ? const Text('No leave types set up yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
          : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [for (final b in _leaveBalance) _leaveTile(b)],
            ),
    );
  }

  Widget _leaveTile(LeaveBalanceItem b) {
    final hasQuota = b.quota != null && b.quota! > 0;
    final remainingFrac = hasQuota ? ((b.remaining ?? 0) / b.quota!).clamp(0.0, 1.0) : 0.0;
    final barColor = remainingFrac <= 0.25 ? AppColors.warning : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: hasQuota ? LeaveBalanceItem.fmt(b.remaining ?? 0) : LeaveBalanceItem.fmt(b.used), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            TextSpan(text: hasQuota ? '  of ${LeaveBalanceItem.fmt(b.quota!)}' : '  used', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          const SizedBox(height: 2),
          Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (hasQuota) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: remainingFrac, minHeight: 7, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(barColor)),
            ),
          ],
          if (b.pending > 0) ...[
            const SizedBox(height: 4),
            Text('${LeaveBalanceItem.fmt(b.pending)} pending', style: const TextStyle(fontSize: 11, color: AppColors.warning)),
          ],
        ],
      ),
    );
  }

  // ---------------- month calendar ----------------

  Color _dayColor(CalendarDay d) {
    switch (d.status) {
      case 'Present':
        return AppColors.present;
      case 'HalfDay':
        return AppColors.halfDay;
      case 'Absent':
        return AppColors.absent;
      case 'Leave':
        return AppColors.onLeave;
      case 'Holiday':
        return AppColors.holiday;
      default:
        return Colors.transparent;
    }
  }

  Widget _calendarCard() {
    final cal = _calendar;
    final days = cal?.days ?? const <CalendarDay>[];
    final lead = days.isEmpty ? 0 : days.first.weekday;
    final label = DateFormat('MMMM y').format(_calMonth);

    return HomeCard(
      title: '$label attendance',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(onTap: () => _moveMonth(-1), borderRadius: BorderRadius.circular(20), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.chevron_left, size: 22))),
          InkWell(
            onTap: _isCurrentMonth ? null : () => _moveMonth(1),
            borderRadius: BorderRadius.circular(20),
            child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.chevron_right, size: 22, color: _isCurrentMonth ? AppColors.border : null)),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final h in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(child: Center(child: Text(h, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)))),
            ],
          ),
          const SizedBox(height: 6),
          if (cal == null)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (final d in days) _dayCell(d),
              ],
            ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot('Present', AppColors.present),
              _LegendDot('Half day', AppColors.halfDay),
              _LegendDot('Absent', AppColors.absent),
              _LegendDot('Leave', AppColors.onLeave),
              _LegendDot('Holiday', AppColors.holiday),
              _LegendDot('Today', AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(CalendarDay d) {
    final color = _dayColor(d);
    final muted = d.status == 'WeekOff' || d.status == 'Future' || d.status == 'NA';
    final isToday = d.isToday;
    return Tooltip(
      message: [if ((d.note ?? '').isNotEmpty) d.note!, d.status, if (d.isWfh) 'WFH'].join(' · '),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isToday ? AppColors.primary : color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${d.dayNo}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday || !muted && color != Colors.transparent ? FontWeight.w700 : FontWeight.w400,
            color: isToday ? Colors.white : (muted ? AppColors.textSecondary : (color == Colors.transparent ? AppColors.textPrimary : color)),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
