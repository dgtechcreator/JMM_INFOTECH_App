import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/session.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/employee/employee_shell.dart';
import 'services/auth_service.dart';
import 'services/notification_router.dart';
import 'services/push_notification_service.dart';
import 'services/trip_tracking_service.dart';
import 'theme/app_theme.dart';

bool _handlingEndedSession = false;

/// A request that carried a token came back 401: the session ended (signed out from another device — e.g.
/// "log out of all other phones" or an admin forced logout — or the password was changed, or it expired).
/// Really sign out and land on Login instead of leaving every screen showing "Unauthorized".
Future<void> _onSessionEnded() async {
  if (_handlingEndedSession) return;
  final context = navigatorKey.currentContext;
  if (context == null) return;
  final session = context.read<Session>();
  if (session.status != AuthStatus.signedIn) return;

  _handlingEndedSession = true;
  try {
    // notifyServer: false — the token is already dead, there is nothing left to tell the server.
    await session.signOut(notifyServer: false);
    navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    final messenger = navigatorKey.currentContext;
    if (messenger != null && messenger.mounted) {
      ScaffoldMessenger.of(messenger).showSnackBar(const SnackBar(content: Text('You were signed out. Please sign in again.')));
    }
  } finally {
    _handlingEndedSession = false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.onUnauthorized = () => unawaited(_onSessionEnded());
  // Firebase push and the background location service are native (Android/iOS) features. A Flutter WEB build —
  // only ever used to eyeball UI changes quickly in a browser — has neither configured, and awaiting their
  // init there throws before runApp() and leaves a blank page.
  if (!kIsWeb) {
    await PushNotificationService.initialize();
    await TripTrackingService.initialize();
  }
  runApp(const JmmEmployeeApp());
}

class JmmEmployeeApp extends StatelessWidget {
  const JmmEmployeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Session(),
      child: MaterialApp(
        title: 'JMM Employee',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.light(),
        home: const _SplashGate(),
      ),
    );
  }
}

/// Restores a persisted token/session (if any) before deciding whether to land on Login or the
/// appropriate shell — mirrors the web app's own session-cookie persistence, just token-based.
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final session = context.read<Session>();
    await session.restore();
    if (!mounted) return;

    if (session.status == AuthStatus.signedIn) {
      unawaited(PushNotificationService.registerToken());
      // Links a session that predates login tracking to this phone, and refreshes app version/last-active.
      unawaited(AuthService().registerSessionDevice(session.loginType));
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => session.loginType == 'Employee' ? const EmployeeShell() : const AdminShell()),
      );
      // A notification tap launched the app from fully closed (getInitialMessage) — the navigator
      // wasn't attached yet when PushNotificationService.initialize() saw it, so act on it now that the
      // signed-in shell is up. Cleared immediately so it doesn't re-fire on a later hot-restart.
      final notifyType = PushNotificationService.pendingNotifyType;
      PushNotificationService.pendingNotifyType = null;
      if (notifyType != null) {
        unawaited(routeForNotifyType(notifyType));
      }
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Icon(Icons.business_center_rounded, color: Colors.white, size: 56),
      ),
    );
  }
}
