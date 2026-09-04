import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/attendance_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../employee/employee_shell.dart';
import '../employee/notifications_screen.dart';
import 'approvals_screen.dart';
import 'employees_screen.dart';
import 'task_assignment_screen.dart';
import 'team_attendance_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = AttendanceService();
  final _notificationService = AppNotificationService();
  AdminDashboardSummary? _summary;
  int _unreadNotifications = 0;
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
      final results = await Future.wait([_service.getAdminDashboardSummary(), _notificationService.getUnreadCount()]);
      if (mounted) {
        setState(() {
          _summary = results[0] as AdminDashboardSummary;
          _unreadNotifications = results[1] as int;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _logout() async {
    await context.read<Session>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadNotifications > 0,
              label: Text('$_unreadNotifications'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              _load();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'employee') {
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const EmployeeShell()), (r) => false);
              } else if (v == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              if (session.employeeId != 0) const PopupMenuItem(value: 'employee', child: Text('Switch to Employee view')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
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
                          Expanded(child: Text('Welcome back, ${session.userName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _tappableStat(
                            'Total Employees', '${_summary?.totalEmployees ?? 0}', AppColors.info, Icons.groups_outlined,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeesScreen())),
                          ),
                          _tappableStat(
                            'Present Today', '${_summary?.presentToday ?? 0}', AppColors.success, Icons.fingerprint,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamAttendanceScreen())),
                          ),
                          _tappableStat(
                            'Pending Leave', '${_summary?.pendingLeaveCount ?? 0}', AppColors.warning, Icons.event_available_outlined,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovalsScreen())),
                          ),
                          _tappableStat(
                            'Pending Reimb.', '${_summary?.pendingReimbursementCount ?? 0}', AppColors.danger, Icons.receipt_long_outlined,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovalsScreen(initialTabIndex: 1))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Quick Actions'),
                      _quickAction(context, 'Team Attendance', Icons.fingerprint, AppColors.info, const TeamAttendanceScreen()),
                      _quickAction(context, 'Approvals', Icons.fact_check_outlined, AppColors.warning, const ApprovalsScreen()),
                      _quickAction(context, 'Assign a Task', Icons.playlist_add_check_outlined, AppColors.success, const TaskAssignmentScreen()),
                    ],
                  ),
                ),
    );
  }

  Widget _tappableStat(String label, String value, Color color, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: StatCard(label: label, value: value, color: color, icon: icon),
    );
  }

  Widget _quickAction(BuildContext context, String label, IconData icon, Color color, Widget screen) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      ),
    );
  }
}
