import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// "Edit profile": the person's own basic details, including the username they sign in with. The server
/// validates everything again and writes both the login record and the HR employee record, so what an
/// employee changes here is what HR and the admin screens show too.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final ProfileDetail profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _service = ProfileService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _username;
  late final TextEditingController _email;
  late final TextEditingController _mobile;
  late final TextEditingController _address;
  String _gender = 'Male';
  DateTime? _dob;
  bool _saving = false;

  // Live "is this username free?" hint.
  Timer? _usernameTimer;
  String? _usernameHint;
  bool _usernameOk = true;
  bool _checkingUsername = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _first = TextEditingController(text: p.firstName);
    _last = TextEditingController(text: p.lastName);
    _username = TextEditingController(text: p.username);
    _email = TextEditingController(text: p.email);
    _mobile = TextEditingController(text: p.contact);
    _address = TextEditingController(text: p.address);
    _gender = p.gender == 'Female' ? 'Female' : 'Male';
    _dob = DateTime.tryParse(p.dob);
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    for (final c in [_first, _last, _username, _email, _mobile, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  static final _usernameRegex = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._\-]{3,29}$');

  void _onUsernameChanged(String value) {
    _usernameTimer?.cancel();
    final v = value.trim();
    if (v == widget.profile.username) {
      setState(() {
        _usernameHint = 'This is your current username.';
        _usernameOk = true;
        _checkingUsername = false;
      });
      return;
    }
    if (!_usernameRegex.hasMatch(v)) {
      setState(() {
        _usernameHint = '4-30 characters: letters, numbers, dot, underscore or hyphen (no spaces).';
        _usernameOk = false;
        _checkingUsername = false;
      });
      return;
    }
    setState(() => _checkingUsername = true);
    _usernameTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final (available, message) = await _service.checkUsername(v);
        if (!mounted || _username.text.trim() != v) return;
        setState(() {
          _usernameHint = message;
          _usernameOk = available;
          _checkingUsername = false;
        });
      } catch (_) {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(now.year - 90),
      lastDate: DateTime(now.year - 14, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_usernameOk) {
      showSnack(context, _usernameHint ?? 'Please choose another username.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _service.updateMyBasicDetails(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        gender: _gender,
        dob: _dob == null ? '' : DateFormat('yyyy-MM-dd').format(_dob!),
        email: _email.text.trim(),
        contactNo: _mobile.text.trim(),
        address: _address.text.trim(),
        userName: _username.text.trim(),
      );
      if (!mounted) return;
      final session = context.read<Session>();
      // Employee logins show the person's full name; Admin logins show the account handle.
      await session.updateDisplayName(session.loginType == 'Employee' ? '${_first.text.trim()} ${_last.text.trim()}' : result.userName);
      if (!mounted) return;
      showSnack(context, result.usernameChanged ? 'Saved. Your username is now "${result.userName}" — use it next time you sign in.' : 'Your details were saved.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save. Please check your connection and try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v, String what) => (v == null || v.trim().isEmpty) ? 'Please enter $what' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _first,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'First name'),
                    validator: (v) => _required(v, 'your first name'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _last,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    validator: (v) => _required(v, 'your last name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _username,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: _onUsernameChanged,
              decoration: InputDecoration(
                labelText: 'Username (you sign in with this)',
                prefixIcon: const Icon(Icons.alternate_email),
                suffixIcon: _checkingUsername
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : (_usernameHint == null ? null : Icon(_usernameOk ? Icons.check_circle : Icons.error, color: _usernameOk ? AppColors.success : AppColors.danger)),
                helperText: _usernameHint ?? 'If you change it, use the new one the next time you sign in.',
                helperMaxLines: 2,
                helperStyle: TextStyle(color: _usernameHint == null ? AppColors.textSecondary : (_usernameOk ? AppColors.success : AppColors.danger)),
              ),
              validator: (v) => _required(v, 'a username'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Please enter your email';
                if (s.length > 50) return 'Email is too long (maximum 50 characters)';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Please enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) {
                var digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length == 12 && digits.startsWith('91')) digits = digits.substring(2);
                if (digits.length == 11 && digits.startsWith('0')) digits = digits.substring(1);
                return RegExp(r'^[6-9][0-9]{9}$').hasMatch(digits) ? null : 'Please enter a valid 10-digit mobile number';
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc_outlined)),
              items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female'))],
              onChanged: (v) => setState(() => _gender = v ?? 'Male'),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date of birth', prefixIcon: Icon(Icons.cake_outlined)),
                child: Text(_dob == null ? 'Select date of birth' : DateFormat('d MMM yyyy').format(_dob!),
                    style: TextStyle(color: _dob == null ? AppColors.textSecondary : AppColors.textPrimary)),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _address,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Address', alignLabelWithHint: true, prefixIcon: Icon(Icons.home_outlined)),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Please enter your address' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save changes'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Department, designation, salary and joining date are managed by HR and can\'t be changed here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
