import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/session.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/employee/employee_shell.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initialize();
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => session.loginType == 'Employee' ? const EmployeeShell() : const AdminShell()),
      );
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
