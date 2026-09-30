import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/admin/approvals_screen.dart';
import '../screens/admin/payroll_screen.dart';
import '../screens/admin/task_assignment_screen.dart';
import '../screens/admin/team_attendance_screen.dart';
import '../screens/admin/visit_assignment_screen.dart';
import '../screens/employee/attendance_screen.dart';
import '../screens/employee/leave_screen.dart';
import '../screens/employee/my_visits_screen.dart';
import '../screens/employee/notifications_screen.dart';
import '../screens/employee/overtime_screen.dart';
import '../screens/employee/reimbursement_screen.dart';
import '../screens/employee/salary_screen.dart';
import '../screens/employee/tasks_screen.dart';
import '../screens/employee/wfh_screen.dart';
import '../screens/profile/login_activity_screen.dart';

/// Global key so a push-notification tap can navigate even when it fires outside any widget's
/// BuildContext (app backgrounded or fully terminated) — see PushNotificationService.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Same key Session uses for SharedPreferences (see core/session.dart) — read directly here rather
/// than through Provider, since this can run before any widget (and therefore any BuildContext) exists.
const String _loginTypeKey = 'session_loginType';

/// Maps a notification's NotifyType (see MVC.Services/NotificationService.cs) to the screen the tapping
/// user actually needs — which differs by role: an admin's "Leave"/"Reimbursement" reminder is about an
/// EMPLOYEE'S request needing the admin's attention (open Approvals), while an employee's own "Leave"/
/// "Reimbursement" notification is about their own request status (open their Leave/Reimbursement tab).
Future<void> routeForNotifyType(String? notifyType) async {
  if (notifyType == null || notifyType.isEmpty) return;

  final nav = navigatorKey.currentState;
  if (nav == null) return;

  final prefs = await SharedPreferences.getInstance();
  final isAdmin = (prefs.getString(_loginTypeKey) ?? 'Employee') == 'Admin';

  Widget screen;
  switch (notifyType) {
    case 'Leave':
      screen = isAdmin ? const ApprovalsScreen(initialTabIndex: 0) : const LeaveScreen();
      break;
    case 'Reimbursement':
      screen = isAdmin ? const ApprovalsScreen(initialTabIndex: 1) : const ReimbursementScreen();
      break;
    case 'Overtime':
      screen = isAdmin ? const ApprovalsScreen(initialTabIndex: 2) : const OvertimeScreen();
      break;
    case 'Task':
      screen = isAdmin ? const TaskAssignmentScreen() : const TasksScreen();
      break;
    case 'Visit':
      screen = isAdmin ? const VisitAssignmentScreen() : const MyVisitsScreen();
      break;
    case 'Salary':
      screen = isAdmin ? const PayrollScreen() : const SalaryScreen();
      break;
    case 'Attendance':
      screen = isAdmin ? const TeamAttendanceScreen() : const AttendanceScreen();
      break;
    case 'WFH':
      // Admin: the WFH tab of Approvals (index 3); employee: their own Work From Home screen.
      screen = isAdmin ? const ApprovalsScreen(initialTabIndex: 3) : const WfhScreen();
      break;
    case 'Security':
      // Password/username changed, signed out remotely: show where the account is signed in.
      screen = const LoginActivityScreen();
      break;
    default:
      screen = const NotificationsScreen();
  }

  nav.push(MaterialPageRoute(builder: (_) => screen));
}
