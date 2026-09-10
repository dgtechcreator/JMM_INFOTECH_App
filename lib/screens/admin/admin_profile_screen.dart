import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../employee/employee_shell.dart';

/// Admin-side counterpart to employee/profile_screen.dart — was missing entirely (AdminShell had no
/// Profile tab at all), so an Admin login had no way to view their own info, change their photo, or log
/// out except the bare "Logout" popup-menu item on the dashboard. Reuses the same ProfileService
/// (GetMyProfile/UploadProfilePhoto are already generic per-token, not employee-specific).
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
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
      final bustedUrl = '$photoUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      await context.read<Session>().updatePhotoUrl(bustedUrl);
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
    final photoUrl = resolvePhotoUrl(session.photoUrl ?? _profile?.photoUrl);

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
                    const SizedBox(height: 2),
                    const Text('Admin', style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_profile != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contact details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 12),
                    _detailRow('Username', _profile!.username),
                    _detailRow('Contact', _profile!.contact),
                    _detailRow('Address', _profile!.address),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
