import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_lock.dart';
import '../core/session.dart';
import '../screens/auth/login_screen.dart';
import '../services/notification_router.dart' show navigatorKey;
import '../theme/app_theme.dart';

/// Sits above the whole Navigator (MaterialApp.builder, inside AppGate) and covers every screen with the
/// unlock screen while the app lock is on and locked. Only ever shown to a signed-in user - the login screen
/// is never locked. See [AppLockController] for when the lock engages.
class AppLockGate extends StatelessWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockController>();
    final session = context.watch<Session>();

    // Signing out (by choice or because the session ended) switches the lock off for the next sign-in.
    if (session.status == AuthStatus.signedOut && (lock.enabled || lock.locked)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => lock.onSignedOut());
    }

    final show = lock.enabled && lock.locked && session.status == AuthStatus.signedIn;
    return Stack(
      children: [
        child,
        if (show) const Positioned.fill(child: _LockScreen()),
      ],
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Prompt straight away. Not repeated on every resume: after the user cancels, the app resumes too, and
    // re-prompting then would trap them in a loop - they tap Unlock (or Sign out) instead.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    await context.read<AppLockController>().unlock();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in with your username and password again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<Session>().signOut();
    navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockController>();
    final name = context.read<Session>().userName;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.fingerprint, color: Colors.white, size: 60),
                  ),
                  const SizedBox(height: 24),
                  const Text('App locked', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    name.isEmpty ? 'Verify it is you to continue.' : 'Welcome back, $name.\nVerify it is you to continue.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                  if (lock.lastError != null) ...[
                    const SizedBox(height: 14),
                    Text(lock.lastError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _checking ? null : _unlock,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(_checking ? 'Checking...' : 'Unlock'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark, minimumSize: const Size(220, 50)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Sign out', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
