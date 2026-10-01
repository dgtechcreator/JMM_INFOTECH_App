import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/session.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/login_screen.dart';
import '../admin/admin_shell.dart';
import '../profile/change_password_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/login_activity_screen.dart';
import '../profile/notification_settings_screen.dart';
import 'attendance_screen.dart';
import 'daily_log_screen.dart';
import 'documents_screen.dart';
import 'leave_screen.dart';
import 'notifications_screen.dart';
import 'reimbursement_screen.dart';
import 'salary_screen.dart';
import 'tasks_screen.dart';
import 'wfh_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = ProfileService();
  ProfileDetail? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _service.getMyProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  Future<void> _logout() async {
    await context.read<Session>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)));
    if (changed == true) _loadProfile();
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final profile = _profile;
    final name = profile != null && profile.fullName.isNotEmpty ? profile.fullName : session.userName;

    final items = <_MenuItem>[
      _MenuItem('Attendance', Icons.fingerprint, () => _open(const AttendanceScreen())),
      _MenuItem('Leave', Icons.event_available_outlined, () => _open(const LeaveScreen())),
      _MenuItem('Work From Home', Icons.home_work_outlined, () => _open(const WfhScreen())),
      _MenuItem('My Tasks', Icons.checklist_outlined, () => _open(const TasksScreen())),
      _MenuItem('Daily Log', Icons.edit_note_outlined, () => _open(const DailyLogScreen())),
      _MenuItem('Reimbursement', Icons.receipt_long_outlined, () => _open(const ReimbursementScreen())),
      _MenuItem('Salary & Payslips', Icons.account_balance_wallet_outlined, () => _open(const SalaryScreen())),
      _MenuItem('My Documents', Icons.description_outlined, () => _open(const DocumentsScreen())),
      _MenuItem('Notifications', Icons.notifications_outlined, () => _open(const NotificationsScreen())),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ProfileAvatar(name: name, radius: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    // The person's OWN email (USERDETAILS/Employees) — not the company's helpdesk address.
                    if (profile != null && profile.email.isNotEmpty)
                      Text(profile.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    if (profile != null && profile.username.isNotEmpty)
                      Text('@${profile.username}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (profile != null && (profile.designation.isNotEmpty || profile.department.isNotEmpty))
                      Text([profile.designation, profile.department].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: profile == null ? null : _editProfile,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit profile'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
          const SizedBox(height: 20),
          if (session.hasAdminAccess) ...[
            Card(
              color: AppColors.primarySoft,
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primaryDark),
                title: const Text('Switch to Admin view', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AdminShell()), (r) => false);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: items.map((item) {
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: item.onTap,
                child: Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                        child: Icon(item.icon, color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 8),
                      // A single long word ("Reimbursement") would otherwise break mid-word on narrow phones.
                      item.label.contains(' ')
                          ? Text(item.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(item.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                            ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Account & security', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _securityTile(Icons.lock_outline, 'Change password', 'Sign-in password for this account', () => _open(const ChangePasswordScreen())),
                const Divider(height: 1),
                _securityTile(Icons.devices_other_outlined, 'My login activity', 'Phones signed in to your account, and when', () => _open(const LoginActivityScreen())),
                const Divider(height: 1),
                _securityTile(Icons.notifications_active_outlined, 'Notification settings', 'Check that alerts reach this phone', () => _open(const NotificationSettingsScreen())),
                const Divider(height: 1),
                _securityTile(Icons.privacy_tip_outlined, 'Privacy policy', 'How your information is collected and used', () => context.read<AppConfigController>().openPrivacyPolicy()),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.danger),
            label: const Text('Logout', style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _securityTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryDark),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _MenuItem {
  _MenuItem(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}
