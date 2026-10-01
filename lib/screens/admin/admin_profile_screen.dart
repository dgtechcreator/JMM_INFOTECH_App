import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/session.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_avatar.dart';
import '../auth/login_screen.dart';
import '../employee/employee_shell.dart';
import '../profile/change_password_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/login_activity_screen.dart';
import '../profile/notification_settings_screen.dart';

/// Admin-side counterpart to employee/profile_screen.dart — was missing entirely (AdminShell had no
/// Profile tab at all), so an Admin login had no way to view their own info, change their photo, or log out
/// except the bare "Logout" popup-menu item on the dashboard. Reuses the same ProfileService
/// (GetMyProfile/UploadProfilePhoto are already generic per-token, not employee-specific), and the same
/// shared avatar (full-screen preview + camera/gallery), edit-profile, password and login-activity screens.
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
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
                    if (profile?.email.isNotEmpty ?? false) Text(profile!.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 2),
                    const Text('Admin', style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
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
          if (profile != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contact details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 12),
                    _detailRow('Username', profile.username),
                    _detailRow('Mobile', profile.contact),
                    _detailRow('Address', profile.address),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
          const SizedBox(height: 16),
          if (session.employeeId != 0) ...[
            Card(
              color: AppColors.primarySoft,
              child: ListTile(
                leading: const Icon(Icons.badge_outlined, color: AppColors.primaryDark),
                title: const Text('Switch to Employee view', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const EmployeeShell()), (r) => false);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
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

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
