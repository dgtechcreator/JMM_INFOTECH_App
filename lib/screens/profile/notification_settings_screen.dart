import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api_client.dart';
import '../../services/push_notification_service.dart';
import '../../theme/app_theme.dart';

/// Self-service check that notifications really reach this phone: is the OS allowing them, and does a real
/// push sent by the server arrive? (When a push "never shows up", the cause is one of: the OS permission is
/// off, the phone's battery manager is killing the app, this phone isn't registered with the server, or the
/// server can't reach Firebase — this screen separates the first from the rest in one tap.)
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  bool? _allowed;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the system Settings page after flipping the switch there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final allowed = await PushNotificationService.notificationsAllowed();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _turnOn() async {
    final granted = await PushNotificationService.requestNotificationPermission();
    if (!granted) {
      // After a "Don't allow" Android won't show the prompt again — the only way back is system Settings.
      await openAppSettings();
    }
    await _refresh();
  }

  Future<void> _sendTest() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      // Make sure this phone is registered first (a fresh install may not have reached the server yet).
      await PushNotificationService.registerToken();
      final detail = await PushNotificationService.sendTestNotification();
      if (!mounted) return;
      setState(() {
        _testResult = detail;
        _testOk = detail.startsWith('Sent');
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _testResult = e.message; _testOk = false; });
    } catch (_) {
      if (mounted) setState(() { _testResult = 'Could not reach the server. Check your internet connection.'; _testOk = false; });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(allowed == false ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                          color: allowed == false ? AppColors.danger : AppColors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          allowed == null ? 'Checking…' : (allowed ? 'Notifications are allowed' : 'Notifications are turned off for this app'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (allowed == false) ...[
                    const SizedBox(height: 8),
                    const Text('You won\'t see visit assignments, approvals or reminders in your notification panel until this is on.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _turnOn, child: const Text('Turn on notifications')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Send a test notification', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('The server sends a real push to this phone. Close or minimise the app right after tapping to see it arrive in the notification panel.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _sendTest,
                    icon: _testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_outlined, size: 18),
                    label: const Text('Send test'),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_testOk ? AppColors.success : AppColors.warning).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_testOk ? Icons.check_circle_outline : Icons.info_outline, size: 18, color: _testOk ? AppColors.success : AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_testResult!, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Not arriving while the app is closed?', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text(
                    'Some phones (Xiaomi/Redmi, Realme/Oppo, Vivo, OnePlus…) stop apps that are closed from receiving anything. '
                    'Open App info for this app and allow "Autostart", set battery to "No restrictions", and keep it unlocked in Recent apps.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: openAppSettings, icon: const Icon(Icons.settings_outlined, size: 18), label: const Text('Open app settings')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
