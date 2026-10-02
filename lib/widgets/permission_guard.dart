import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/location_disclosure.dart';

/// Keeps asking — politely, again and again — until the phone has the permissions the app really depends on:
///   * Location "Allow all the time" (field-visit trips keep recording when the app is closed; without it the
///     route silently stops the moment the screen turns off),
///   * Notifications (approvals / reminders / alerts reach the phone).
/// Checked when the shell opens and every time the app returns to the foreground (so coming back from the
/// Settings page re-checks immediately), but the dialog itself is shown at most once every [_gap] so it never
/// becomes a loop. Android 11+ cannot grant "all the time" from an in-app dialog: the second step opens the
/// system Settings page, which is why the dialog says exactly which option to choose there.
/// Background location is only ever requested after the Play-policy disclosure ([LocationDisclosure]).
class PermissionGuard extends StatefulWidget {
  const PermissionGuard({super.key, required this.child, this.needsLocation = true});
  final Widget child;

  /// false for the admin shell: admins don't record trips.
  final bool needsLocation;

  @override
  State<PermissionGuard> createState() => _PermissionGuardState();
}

class _PermissionGuardState extends State<PermissionGuard> with WidgetsBindingObserver {
  static const _gap = Duration(minutes: 10);
  // static: survives the shell being rebuilt (e.g. switching Admin <-> Employee view) within the same process.
  static DateTime? _lastPrompt;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<({bool location, bool notifications})> _missing() async {
    var location = false;
    var notifications = false;
    try {
      if (widget.needsLocation) {
        location = await Geolocator.checkPermission() != LocationPermission.always;
      }
      notifications = !(await Permission.notification.status).isGranted;
    } catch (_) {
      // A permission plugin hiccup must never block the app.
    }
    return (location: location, notifications: notifications);
  }

  Future<void> _check() async {
    if (kIsWeb || _busy || !mounted) return;
    final missing = await _missing();
    if (!mounted || (!missing.location && !missing.notifications)) return;

    final last = _lastPrompt;
    if (last != null && DateTime.now().difference(last) < _gap) return;
    _busy = true;
    _lastPrompt = DateTime.now();
    try {
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.shield_outlined, size: 32),
          title: const Text('Permissions needed'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('For the app to work properly please allow:'),
                const SizedBox(height: 12),
                if (missing.location)
                  const _Need(
                    icon: Icons.location_on_outlined,
                    title: 'Location - "Allow all the time"',
                    text: 'So your field-visit trips keep recording even when the app is closed or the screen is off. '
                        'On the next screen choose "Allow all the time".',
                  ),
                if (missing.notifications)
                  const _Need(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notifications',
                    text: 'So approvals, reminders and alerts reach your phone.',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Continue')),
          ],
        ),
      );
      if (go == true && mounted) await _grant(missing);
    } finally {
      _busy = false;
    }
  }

  Future<void> _grant(({bool location, bool notifications}) missing) async {
    try {
      if (missing.location) {
        if (!mounted || !await LocationDisclosure.ensureAccepted(context)) return;
        var p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
        if (p == LocationPermission.whileInUse) {
          // Android 11+: opens the system page where "Allow all the time" is chosen.
          await Permission.locationAlways.request();
        } else if (p == LocationPermission.deniedForever) {
          await openAppSettings();
        }
      }
      if (missing.notifications) {
        final status = await Permission.notification.request();
        if (status.isPermanentlyDenied) await openAppSettings();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Need extends StatelessWidget {
  const _Need({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
