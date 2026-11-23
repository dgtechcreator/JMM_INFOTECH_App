import 'package:flutter/material.dart';

import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_lock_tile.dart';
import '../../widgets/permission_guard.dart';
import 'attendance_screen.dart';
import 'home_screen.dart';
import 'leave_screen.dart';
import 'tasks_screen.dart';
import 'profile_screen.dart';

class EmployeeShell extends StatefulWidget {
  const EmployeeShell({super.key});

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // First time on this phone: offer fingerprint / face unlock (once; never nags after "Not now"). Delayed so it
    // does not land on top of the permission prompts the shell shows on first launch.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) offerAppLockOnce(context);
    });
  }

  final _screens = const [
    HomeScreen(),
    AttendanceScreen(),
    LeaveScreen(),
    TasksScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    AppNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    AppNavItem(icon: Icons.fingerprint_outlined, activeIcon: Icons.fingerprint, label: 'Attendance'),
    AppNavItem(icon: Icons.event_available_outlined, activeIcon: Icons.event_available, label: 'Leave'),
    AppNavItem(icon: Icons.checklist_outlined, activeIcon: Icons.checklist, label: 'Tasks'),
    AppNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      child: Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: AppBottomNav(items: _items, currentIndex: _index, onTap: (i) => setState(() => _index = i)),
      ),
    );
  }
}
