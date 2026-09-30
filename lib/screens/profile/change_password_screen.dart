import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Change password. Needs the CURRENT password (proof it's really the owner holding the phone), enforces the
/// same rules as the server, and — as with any credential change — signs every OTHER device out while this
/// phone stays signed in.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _service = ProfileService();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // Mirrors ProfileService.ValidatePassword on the server (6-16 printable ASCII, a letter and a number).
  bool get _lengthOk => _new.text.length >= 6 && _new.text.length <= 16;
  bool get _letterOk => RegExp(r'[A-Za-z]').hasMatch(_new.text);
  bool get _numberOk => RegExp(r'[0-9]').hasMatch(_new.text);
  bool get _charsOk => _new.text.isEmpty || RegExp(r'^[\x21-\x7E]+$').hasMatch(_new.text);
  bool get _matches => _new.text.isNotEmpty && _new.text == _confirm.text;

  Future<void> _save() async {
    if (_current.text.isEmpty) {
      showSnack(context, 'Please enter your current password.', isError: true);
      return;
    }
    if (!_lengthOk || !_letterOk || !_numberOk || !_charsOk) {
      showSnack(context, 'Your new password doesn\'t meet the rules below yet.', isError: true);
      return;
    }
    if (!_matches) {
      showSnack(context, 'New password and confirm password do not match.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final signedOut = await _service.changePassword(currentPassword: _current.text, newPassword: _new.text, confirmPassword: _confirm.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 40),
          title: const Text('Password changed'),
          content: Text(signedOut > 0
              ? 'Your password was updated and $signedOut other device${signedOut == 1 ? ' was' : 's were'} signed out. You stay signed in on this phone.'
              : 'Your password was updated. You stay signed in on this phone.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not change the password. Please check your connection and try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _rule(bool ok, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: ok ? AppColors.success : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, color: ok ? AppColors.success : AppColors.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _current,
            obscureText: !_showCurrent,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Current password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_showCurrent ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _showCurrent = !_showCurrent)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _new,
            obscureText: !_showNew,
            maxLength: 16,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'New password',
              counterText: '',
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _showNew = !_showNew)),
            ),
          ),
          _rule(_lengthOk, '6 to 16 characters'),
          _rule(_letterOk, 'At least one letter'),
          _rule(_numberOk, 'At least one number'),
          if (!_charsOk) _rule(false, 'Letters, numbers and symbols only (no spaces)'),
          const SizedBox(height: 14),
          TextField(
            controller: _confirm,
            obscureText: !_showNew,
            maxLength: 16,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Confirm new password', counterText: '', prefixIcon: Icon(Icons.key_outlined)),
          ),
          if (_confirm.text.isNotEmpty) _rule(_matches, _matches ? 'Passwords match' : 'Passwords don\'t match yet'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update password'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Changing your password signs you out of your other phones — a good habit if you ever suspect someone else has used your account.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
