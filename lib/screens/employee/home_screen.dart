import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../core/location_helper.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/attendance_service.dart';
import '../../services/notification_service.dart';
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/swipe_button.dart';
import 'daily_log_screen.dart';
import 'documents_screen.dart';
import 'my_visits_screen.dart';
import 'notifications_screen.dart';
import 'overtime_screen.dart';
import 'reimbursement_screen.dart';
import 'salary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _attendanceService = AttendanceService();
  final _taskService = TaskService();
  final _notificationService = AppNotificationService();

  AttendanceRecord? _today;
  int _pendingTasks = 0;
  int _unreadNotifications = 0;
  bool _loading = true;
  bool _punchBusy = false;
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
      final results = await Future.wait([
        _attendanceService.getTodayStatus(),
        _taskService.getMyTasks(),
        _notificationService.getUnreadCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _today = results[0] as AttendanceRecord?;
        _pendingTasks = (results[1] as List<TaskItem>).where((t) => t.status.toLowerCase() != 'completed' && t.status.toLowerCase() != 'closed').length;
        _unreadNotifications = results[2] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _punch(bool isPunchIn) async {
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

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(
        title: Text('Good ${_greeting()},', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text('$_unreadNotifications'),
              child: const Icon(Icons.notifications_outlined),
            ),
            // HomeScreen is kept alive inside EmployeeShell's IndexedStack, so it never re-runs initState
            // when the user comes back from the bell — without awaiting this push and reloading, the
            // unread badge would keep showing the pre-visit count even after the user reads/marks
            // everything as read on NotificationsScreen.
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              if (mounted) _load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingView()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primarySoft,
                        backgroundImage: resolvePhotoUrl(session.photoUrl) != null ? NetworkImage(resolvePhotoUrl(session.photoUrl)!) : null,
                        child: resolvePhotoUrl(session.photoUrl) == null
                            ? Text(
                                session.userName.isNotEmpty ? session.userName[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(session.userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ErrorView(message: _error!, onRetry: _load),
                  _buildPunchCard(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: StatCard(label: 'Pending Tasks', value: '$_pendingTasks', color: AppColors.info, icon: Icons.checklist)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'This Month',
                          value: _today?.statusId ?? '-',
                          color: statusColor(_today?.statusId ?? ''),
                          icon: Icons.event_available,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Quick Actions'),
                  _buildQuickActions(),
                ],
              ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Widget _buildPunchCard() {
    final hasPunchedIn = _today?.punchInTime != null;
    final hasPunchedOut = _today?.punchOutTime != null;
    final complete = hasPunchedIn && hasPunchedOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('WORKING HOURS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.5)),
                  Text(_formatToday(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(_formatWorkedHours(_today?.workedMinutes ?? 0), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                complete
                    ? "Today's attendance complete"
                    : hasPunchedIn
                        ? 'Currently punched in'
                        : 'You have not punched in yet today.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SwipeToConfirmButton(
                key: ValueKey(hasPunchedIn),
                label: complete ? 'Attendance complete' : (hasPunchedIn ? 'Slide to punch out' : 'Slide to punch in'),
                color: Colors.white.withValues(alpha: 0.25),
                busy: _punchBusy,
                enabled: !complete,
                onConfirm: () => _punch(!hasPunchedIn),
              ),
            ],
          ),
        ),
        if (hasPunchedIn) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Today\'s Activity', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _activityRow(Icons.login_rounded, AppColors.success, 'Punch In', formatTime(_today!.punchInTime)),
                  if (hasPunchedOut) ...[
                    const SizedBox(height: 10),
                    _activityRow(Icons.logout_rounded, AppColors.danger, 'Punch Out', formatTime(_today!.punchOutTime)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _activityRow(IconData icon, Color color, String label, String time) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Text(time, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }

  String _formatWorkedHours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _formatToday() {
    final now = DateTime.now();
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${now.day} ${months[now.month]} ${now.year}';
  }

  Widget _buildQuickActions() {
    final actions = [
      (_QuickAction('Reimbursement', Icons.receipt_long_outlined, AppColors.info, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReimbursementScreen())))),
      (_QuickAction('Daily Log', Icons.edit_note_outlined, AppColors.warning, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyLogScreen())))),
      (_QuickAction('Salary & Payslip', Icons.account_balance_wallet_outlined, AppColors.success, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryScreen())))),
      (_QuickAction('My Visits', Icons.map_outlined, AppColors.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyVisitsScreen())))),
      (_QuickAction('Overtime', Icons.timer_outlined, AppColors.holiday, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OvertimeScreen())))),
      (_QuickAction('My Documents', Icons.description_outlined, AppColors.info, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())))),
      (_QuickAction('Notifications', Icons.notifications_none_rounded, AppColors.onLeave, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())))),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: actions.map((a) {
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: a.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: a.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(a.icon, color: a.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickAction {
  _QuickAction(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
