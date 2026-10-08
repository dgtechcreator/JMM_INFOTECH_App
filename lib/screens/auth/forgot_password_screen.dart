import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../services/password_recovery_service.dart';
import '../../theme/app_theme.dart';

enum _Step { find, otp, help, done }

/// Forgot password, same flow as the web login:
///   1. type your login  ->  registered email: a 6-digit code is emailed, enter it with a new password.
///   2. no email on file ->  send the administrator your name, department, mobile and the email to register; they
///      set it and an emailed link lets you choose a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialIdentifier = ''});

  /// What was already typed in the login box.
  final String initialIdentifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = PasswordRecoveryApi();
  late final TextEditingController _identifier;
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  final _dept = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();

  _Step _step = _Step.find;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String _masked = '';
  String _doneTitle = '';
  String _doneText = '';
  String _identifierSent = '';
  int _resendLeft = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _identifier = TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_identifier, _otp, _newPassword, _confirm, _name, _dept, _mobile, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendLeft--);
      if (_resendLeft <= 0) t.cancel();
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    final id = resend ? _identifierSent : _identifier.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Please enter your username, phone number or email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _api.start(id);
      if (!mounted) return;
      switch (r.status) {
        case 'otp_sent':
          _identifierSent = id;
          _masked = r.maskedEmail ?? '';
          _otp.clear();
          setState(() => _step = _Step.otp);
          _startCountdown();
          break;
        case 'no_email':
          _identifierSent = id;
          setState(() => _step = _Step.help);
          break;
        default:
          setState(() => _error = r.message ?? 'Something went wrong. Please try again.');
          if (resend) _startCountdown();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_otp.text.trim().length != 6) {
      setState(() => _error = 'Please enter the 6-digit code from your email.');
      return;
    }
    if (_newPassword.text.isEmpty) {
      setState(() => _error = 'Please enter a new password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await _api.verifyAndReset(identifier: _identifierSent, otp: _otp.text.trim(), newPassword: _newPassword.text, confirmPassword: _confirm.text);
      if (!mounted) return;
      setState(() {
        _doneTitle = 'Password reset';
        _doneText = msg;
        _step = _Step.done;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendHelp() async {
    if ([_name, _dept, _mobile, _email].any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'Please fill all four fields.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await _api.requestAdminHelp(
        identifier: _identifierSent,
        fullName: _name.text.trim(),
        department: _dept.text.trim(),
        mobile: _mobile.text.trim(),
        email: _email.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _doneTitle = 'Request sent';
        _doneText = msg;
        _step = _Step.done;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(_Step s) => setState(() {
        _step = s;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: switch (_step) {
                    _Step.find => _findStep(),
                    _Step.otp => _otpStep(),
                    _Step.help => _helpStep(),
                    _Step.done => _doneStep(),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorText() => _error == null
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)));

  Widget _primaryButton(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: ElevatedButton(
          onPressed: _busy ? null : onTap,
          child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label),
        ),
      );

  Widget _findStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Forgot your password?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Enter your login and we will email you a code.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 18),
        TextField(
          controller: _identifier,
          autofocus: widget.initialIdentifier.isEmpty,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendCode(),
          decoration: const InputDecoration(labelText: 'Username (Phone / Email)', prefixIcon: Icon(Icons.person_outline)),
        ),
        _errorText(),
        _primaryButton('Send code', _sendCode),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to login')),
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Check your email', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text.rich(TextSpan(style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), children: [
          const TextSpan(text: 'We sent a 6-digit code to '),
          TextSpan(text: _masked, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ])),
        const SizedBox(height: 18),
        TextField(
          controller: _otp,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
          decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: (_busy || _resendLeft > 0) ? null : () => _sendCode(resend: true),
            child: Text(_resendLeft > 0 ? 'Resend code in ${_resendLeft}s' : 'Resend code'),
          ),
        ),
        TextField(
          controller: _newPassword,
          obscureText: _obscure,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'New password',
            helperText: '6-16 characters, with letters and numbers',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscure = !_obscure)),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirm,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _reset(),
          decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline)),
        ),
        _errorText(),
        _primaryButton('Reset password', _reset),
        TextButton(onPressed: () => _goTo(_Step.find), child: const Text('Use a different login')),
      ],
    );
  }

  Widget _helpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ask your administrator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('No email is registered for this login.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'Send your details to the administrator. Once your email is registered you will receive a link to reset your password.',
            style: TextStyle(fontSize: 12.5, color: AppColors.primaryDark),
          ),
        ),
        const SizedBox(height: 16),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 12),
        TextField(controller: _dept, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.apartment_outlined))),
        const SizedBox(height: 12),
        TextField(
          controller: _mobile,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          maxLength: 15,
          decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined), counterText: ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendHelp(),
          decoration: const InputDecoration(labelText: 'Email to register', prefixIcon: Icon(Icons.email_outlined)),
        ),
        _errorText(),
        _primaryButton('Send request to admin', _sendHelp),
        TextButton(onPressed: () => _goTo(_Step.find), child: const Text('Back')),
      ],
    );
  }

  Widget _doneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 56),
        const SizedBox(height: 12),
        Text(_doneTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_doneText, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        _primaryButton('Back to login', () => Navigator.pop(context)),
      ],
    );
  }
}
