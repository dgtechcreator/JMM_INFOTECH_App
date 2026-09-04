import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../admin/admin_shell.dart';
import 'attendance_screen.dart';
import 'daily_log_screen.dart';
import 'leave_screen.dart';
import 'notifications_screen.dart';
import 'reimbursement_screen.dart';
import 'salary_screen.dart';
import 'tasks_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = ProfileService();
  final _picker = ImagePicker();
  ProfileDetail? _profile;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _service.getMyProfile().then((p) {
      if (mounted) setState(() => _profile = p);
    }).catchError((_) {});
  }

  Future<void> _logout() async {
    await context.read<Session>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  Future<void> _changePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final photoUrl = await _service.uploadPhoto(bytes, picked.name);
      if (!mounted) return;
      await context.read<Session>().updatePhotoUrl(photoUrl);
      if (!mounted) return;
      showSnack(context, 'Photo updated.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final photoUrl = resolvePhotoUrl(_profile?.photoUrl ?? session.photoUrl);
    final items = <_MenuItem>[
      _MenuItem('Attendance', Icons.fingerprint, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()))),
      _MenuItem('Leave', Icons.event_available_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveScreen()))),
      _MenuItem('My Tasks', Icons.checklist_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen()))),
      _MenuItem('Daily Log', Icons.edit_note_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyLogScreen()))),
      _MenuItem('Reimbursement', Icons.receipt_long_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReimbursementScreen()))),
      _MenuItem('Salary & Payslips', Icons.account_balance_wallet_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryScreen()))),
      _MenuItem('Notifications', Icons.notifications_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _uploadingPhoto ? null : _changePhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primarySoft,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: _uploadingPhoto
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                          : photoUrl == null
                              ? Text(
                                  session.userName.isNotEmpty ? session.userName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                                )
                              : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_profile != null ? '${_profile!.firstName} ${_profile!.lastName}'.trim() : session.userName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    if (_profile?.email.isNotEmpty ?? false) Text(_profile!.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                      Text(item.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }).toList(),
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
}

class _MenuItem {
  _MenuItem(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}
