import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_shell.dart';
import '../employee/employee_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _loginType = 'Admin';
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter username and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _authService.login(_usernameController.text.trim(), _passwordController.text, _loginType);
      if (!mounted) return;
      final session = context.read<Session>();
      await session.applyLogin(
        token: result.token,
        userId: result.userId,
        userName: result.userName,
        loginType: result.loginType,
        employeeId: result.employeeId,
        hasAdminAccess: result.hasAdminAccess,
        photoUrl: result.photoUrl,
      );
      if (!mounted) return;
      _navigateToShell(result.loginType);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToShell(String loginType) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => loginType == 'Employee' ? const EmployeeShell() : const AdminShell(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Image.asset('assets/images/jmm_logo.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('JMM InfoTech', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Sign in to continue to your workspace', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Login As', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'Admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings_outlined)),
                              ButtonSegment(value: 'Employee', label: Text('Employee'), icon: Icon(Icons.badge_outlined)),
                            ],
                            selected: {_loginType},
                            onSelectionChanged: (s) => setState(() => _loginType = s.first),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.background,
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('© JMM Infotech Pvt. Ltd.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
