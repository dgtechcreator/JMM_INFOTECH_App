import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../theme/app_theme.dart';

/// Sits above the whole Navigator (MaterialApp.builder) so a portal-side "Update required" or "Maintenance"
/// switch takes over EVERY screen — login included — and lifts again as soon as the portal turns it off.
/// Also re-checks the portal's settings whenever the app returns to the foreground (at most every 10 minutes).
class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppConfigController>().refreshIfStale();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigController>();
    Widget? block;
    if (config.forceUpdate) {
      block = const _BlockingScreen(
        icon: Icons.system_update_alt_rounded,
        title: 'Update required',
        kind: _BlockKind.update,
      );
    } else if (config.maintenance) {
      block = const _BlockingScreen(
        icon: Icons.build_circle_outlined,
        title: 'Under maintenance',
        kind: _BlockKind.maintenance,
      );
    }
    return Stack(
      children: [
        widget.child,
        if (block != null) Positioned.fill(child: block),
      ],
    );
  }
}

enum _BlockKind { update, maintenance }

class _BlockingScreen extends StatelessWidget {
  const _BlockingScreen({required this.icon, required this.title, required this.kind});
  final IconData icon;
  final String title;
  final _BlockKind kind;

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigController>();
    final isUpdate = kind == _BlockKind.update;
    final latest = config.config?.latestVersionName ?? '';
    final supportEmail = config.config?.supportEmail ?? '';

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 64),
                  const SizedBox(height: 20),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                    isUpdate ? config.updateMessage : config.maintenanceMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  if (isUpdate && latest.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Latest version: $latest', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                  const SizedBox(height: 28),
                  if (isUpdate)
                    FilledButton.icon(
                      onPressed: config.openUpdatePage,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Update now'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark, minimumSize: const Size(200, 48)),
                    )
                  else
                    FilledButton.icon(
                      onPressed: config.refreshing ? null : config.refresh,
                      icon: config.refreshing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      label: Text(config.refreshing ? 'Checking...' : 'Try again'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark, minimumSize: const Size(200, 48)),
                    ),
                  if (supportEmail.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Need help? $supportEmail', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
