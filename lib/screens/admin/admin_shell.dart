import 'package:flutter/material.dart';

import '../../widgets/app_bottom_nav.dart';
import 'admin_dashboard_screen.dart';
import 'team_attendance_screen.dart';
import 'approvals_screen.dart';
import 'task_assignment_screen.dart';
import 'employees_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  final _screens = const [
    AdminDashboardScreen(),
    TeamAttendanceScreen(),
    ApprovalsScreen(),
    TaskAssignmentScreen(),
    EmployeesScreen(),
  ];

  static const _items = [
    AppNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    AppNavItem(icon: Icons.fingerprint_outlined, activeIcon: Icons.fingerprint, label: 'Attendance'),
    AppNavItem(icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check, label: 'Approvals'),
    AppNavItem(icon: Icons.checklist_outlined, activeIcon: Icons.checklist, label: 'Tasks'),
    AppNavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Payroll'),
  ];

  void _openQuickActions() {
    showQuickActionsSheet(context, [
      QuickActionTile(
        icon: Icons.fingerprint,
        label: 'Mark Attendance',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamAttendanceScreen(autoOpenSheet: true)));
        },
      ),
      QuickActionTile(
        icon: Icons.playlist_add_check_outlined,
        label: 'Assign a Task',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskAssignmentScreen(autoOpenSheet: true)));
        },
      ),
      QuickActionTile(
        icon: Icons.fact_check_outlined,
        label: 'Review Approvals',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovalsScreen()));
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: AppFab(onTap: _openQuickActions),
      bottomNavigationBar: AppBottomNav(items: _items, currentIndex: _index, onTap: (i) => setState(() => _index = i)),
    );
  }
}
