import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../services/login_activity_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// "My Login Activity" / active devices — every phone and browser this account is signed in on (or was),
/// when, from which IP, failed sign-in attempts, and security events (password changed, signed out
/// remotely). Lets a person check "has anyone else logged in as me?" and sign any unknown phone out.
class LoginActivityScreen extends StatefulWidget {
  const LoginActivityScreen({super.key});

  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
  final _service = LoginActivityService();
  List<LoginActivityItem> _items = [];
  LoginActivitySummary? _summary;
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
      final results = await Future.wait([_service.getMyLoginActivity(), _service.getMyLoginActivitySummary()]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<LoginActivityItem>;
        _summary = results[1] as LoginActivitySummary?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _revoke(LoginActivityItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out this phone?'),
        content: Text('${item.deviceName.isEmpty ? 'This device' : item.deviceName} will be signed out immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.revokeSession(item.activityId);
      if (mounted) showSnack(context, 'Signed out.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _logoutOthers() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of all other phones?'),
        content: const Text('Every other phone signed in to your account will be signed out. This phone stays signed in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out all', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final count = await _service.logoutOtherDevices();
      if (mounted) showSnack(context, count == 0 ? 'No other phones were signed in.' : '$count other phone${count == 1 ? '' : 's'} signed out.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _items.where((i) => i.isActiveMobileSession).toList();
    final history = _items.where((i) => !i.isActiveMobileSession).toList();
    final otherActive = active.where((i) => !i.isCurrent).length;

    return Scaffold(
      appBar: AppBar(title: const Text('My Login Activity')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_summary != null) _summaryRow(_summary!),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Text("Where you're signed in", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                          if (otherActive > 0)
                            TextButton(onPressed: _logoutOthers, child: const Text('Log out others', style: TextStyle(color: AppColors.danger))),
                        ],
                      ),
                      const Text("If you see a phone you don't recognise, log it out and change your password.",
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      if (active.isEmpty)
                        const EmptyState(message: 'No phones are signed in right now.', icon: Icons.phonelink_off_outlined)
                      else
                        ...active.map(_activeCard),
                      const SizedBox(height: 20),
                      const Text('Recent activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      if (history.isEmpty)
                        const EmptyState(message: 'Nothing else recorded yet.', icon: Icons.history)
                      else
                        ...history.map(_historyTile),
                      const SizedBox(height: 16),
                      const Text(
                        'Website sign-ins are listed for your information; they end when you log out there or the session times out.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryRow(LoginActivitySummary s) {
    return Row(
      children: [
        Expanded(child: StatCard(label: 'Signed in now', value: '${s.activeSessions}', color: AppColors.success, icon: Icons.smartphone)),
        const SizedBox(width: 10),
        Expanded(child: StatCard(label: 'Failed (7 days)', value: '${s.failedAttempts7d}', color: s.failedAttempts7d > 0 ? AppColors.danger : AppColors.textSecondary, icon: Icons.warning_amber_rounded)),
      ],
    );
  }

  Widget _activeCard(LoginActivityItem it) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.smartphone, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(it.deviceName.isEmpty ? 'Unknown device' : it.deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (it.isCurrent) _pill('This phone', AppColors.success),
                      if (it.sharedCount > 0) _pill('Shared device', AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${it.osVersion.isEmpty ? '' : '${it.osVersion} · '}${it.appVersion.isEmpty ? '' : 'app ${it.appVersion} · '}IP ${it.ipAddress}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text('Signed in ${formatDateTime(it.eventOn)} · active ${formatDateTime(it.lastActiveOn)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (it.sharedCount > 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Another account has also signed in from this phone.', style: TextStyle(fontSize: 12, color: AppColors.warning)),
                    ),
                ],
              ),
            ),
            if (!it.isCurrent)
              TextButton(onPressed: () => _revoke(it), child: const Text('Log out', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _historyTile(LoginActivityItem it) {
    final IconData icon;
    final Color color;
    if (it.isFailedAttempt) {
      icon = Icons.gpp_bad_outlined;
      color = AppColors.danger;
    } else if (it.isEvent) {
      icon = Icons.shield_outlined;
      color = AppColors.warning;
    } else if (it.source == 'Web') {
      icon = Icons.desktop_windows_outlined;
      color = AppColors.info;
    } else {
      icon = Icons.smartphone;
      color = AppColors.textSecondary;
    }

    final lines = <String>[
      if (it.deviceName.isNotEmpty) it.deviceName,
      if (it.ipAddress.isNotEmpty) 'IP ${it.ipAddress}',
      if (it.details != null && it.details!.isNotEmpty) it.details!,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${formatDateTime(it.eventOn)}${lines.isEmpty ? '' : '\n${lines.join(' · ')}'}', style: const TextStyle(fontSize: 12)),
        isThreeLine: lines.isNotEmpty,
        trailing: it.isEvent ? null : _pill(it.status, it.isFailedAttempt ? AppColors.danger : AppColors.textSecondary),
      ),
    );
  }
}
