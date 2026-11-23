import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_lock.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// "Unlock with fingerprint / face" switch for the Profile screens. Turning it on or off needs the user to
/// verify first (see [AppLockController.enable] / [AppLockController.disable]).
class AppLockTile extends StatefulWidget {
  const AppLockTile({super.key});

  @override
  State<AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends State<AppLockTile> {
  bool? _supported;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    context.read<AppLockController>().isSupported().then((v) {
      if (mounted) setState(() => _supported = v);
    });
  }

  Future<void> _toggle(bool on) async {
    final lock = context.read<AppLockController>();
    setState(() => _working = true);
    final ok = on ? await lock.enable() : await lock.disable();
    if (!mounted) return;
    setState(() => _working = false);
    if (ok) {
      showSnack(context, on ? 'Fingerprint unlock is on.' : 'Fingerprint unlock is off.');
    } else if (lock.lastError != null) {
      showSnack(context, lock.lastError!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockController>();
    final supported = _supported ?? true;
    return SwitchListTile(
      value: lock.enabled,
      onChanged: (_working || (!supported && !lock.enabled)) ? null : _toggle,
      activeThumbColor: AppColors.primary,
      secondary: Icon(Icons.fingerprint, color: lock.enabled ? AppColors.primary : AppColors.textSecondary),
      title: const Text('Unlock with fingerprint / face', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        !supported && !lock.enabled
            ? 'Set a screen lock (PIN, pattern or fingerprint) in your phone settings to use this.'
            : 'Ask for your fingerprint, face or phone PIN when the app opens or after it has been away for a minute.',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

/// One-time offer shown the first time a signed-in user reaches the app on this phone. "Not now" is
/// remembered, so it never nags; the switch stays available on the Profile screen.
Future<void> offerAppLockOnce(BuildContext context) async {
  final lock = context.read<AppLockController>();
  if (lock.enabled || await lock.alreadyAsked() || !await lock.isSupported()) return;
  if (!context.mounted) return;
  await lock.markAsked();
  if (!context.mounted) return;
  final turnOn = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.fingerprint, size: 40, color: AppColors.primary),
      title: const Text('Protect your app'),
      content: const Text('Use your fingerprint, face or phone PIN to open JMM InfoTech. You can change this any time in Profile.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Turn on')),
      ],
    ),
  );
  if (turnOn == true && context.mounted) {
    final ok = await lock.enable();
    if (!ok && lock.lastError != null && context.mounted) showSnack(context, lock.lastError!, isError: true);
  }
}
