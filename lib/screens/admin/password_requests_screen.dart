import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../services/password_recovery_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/home_widgets.dart';

/// Admin: people who forgot their password and have no email registered. Check their details against the
/// matched account, set the email, and they get an emailed reset link. Nothing is deleted - a request ends as
/// Resolved or Rejected.
class PasswordRequestsScreen extends StatefulWidget {
  const PasswordRequestsScreen({super.key});

  @override
  State<PasswordRequestsScreen> createState() => _PasswordRequestsScreenState();
}

class _PasswordRequestsScreenState extends State<PasswordRequestsScreen> {
  final _api = PasswordRecoveryApi();
  List<PasswordHelpRequest> _items = [];
  String _status = 'Pending';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getRequests(status: _status);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openResolve(PasswordHelpRequest r) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ResolveSheet(request: r),
    );
    if (done == true) _load();
  }

  Future<void> _reject(PasswordHelpRequest r) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this request?'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Reason (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.reject(r.requestId, remarks: c.text.trim());
      if (mounted) showSnack(context, 'Request closed.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not reach the server.', isError: true);
    }
  }

  Future<void> _resend(PasswordHelpRequest r) async {
    try {
      final msg = await _api.resendLink(r.requestId);
      if (mounted) showSnack(context, msg);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not reach the server.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password Requests')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                for (final s in const ['Pending', 'Resolved', 'Rejected', 'All'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: _status == s,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: _status == s ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: _status == s ? AppColors.primary : AppColors.border),
                      onSelected: (_) {
                        setState(() => _status = s);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _items.isEmpty
                            ? ListView(children: const [EmptyState(message: 'No requests here.', icon: Icons.lock_reset_outlined)])
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                children: [for (final r in _items) _card(r)],
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String? v) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text.rich(TextSpan(style: const TextStyle(fontSize: 12.5), children: [
          TextSpan(text: '$k: ', style: const TextStyle(color: AppColors.textSecondary)),
          TextSpan(text: (v ?? '').isEmpty ? '-' : v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ])),
      );

  Widget _card(PasswordHelpRequest r) {
    final statusColor = r.status == 'Pending' ? AppColors.warning : (r.status == 'Resolved' ? AppColors.success : AppColors.holiday);
    return HomeCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              HomePill(r.status, statusColor),
            ],
          ),
          Text(r.createdOnText, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          const Text('THEY ENTERED', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          _kv('Department', r.department),
          _kv('Mobile', r.mobile),
          _kv('Email to register', r.requestedEmail),
          _kv('Login typed', r.identifier),
          const SizedBox(height: 8),
          const Text('MATCHING ACCOUNT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          if (r.accountUserId == null)
            const Text('No account matched automatically - choose it when you set the email.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))
          else ...[
            _kv('Name', r.accountDisplay),
            _kv('Department', r.accountDepartment),
            _kv('Mobile', r.accountMobile),
            _kv('Current email', r.accountEmail),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              HomePill(r.nameMatches ? 'Name matches' : 'Name differs', r.nameMatches ? AppColors.success : AppColors.danger),
              HomePill(r.mobileMatches ? 'Mobile matches' : 'Mobile differs', r.mobileMatches ? AppColors.success : AppColors.danger),
            ]),
          ],
          if (r.status != 'Pending') ...[
            const SizedBox(height: 8),
            Text(
              '${r.status} by ${r.resolvedByName ?? '-'} on ${r.resolvedOnText ?? ''}${(r.resolvedEmail ?? '').isEmpty ? '' : ' · ${r.resolvedEmail}'}${(r.adminRemarks ?? '').isEmpty ? '' : ' · ${r.adminRemarks}'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          if (r.status == 'Pending')
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openResolve(r),
                    icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                    label: const Text('Send reset link'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _reject(r),
                  // the app theme gives outlined buttons an infinite minimum width, which a Row cannot lay out
                  style: OutlinedButton.styleFrom(minimumSize: const Size(88, 44)),
                  child: const Text('Reject', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            )
          else if (r.canResend)
            OutlinedButton.icon(onPressed: () => _resend(r), icon: const Icon(Icons.send_outlined, size: 18), label: const Text('Resend link')),
        ],
      ),
    );
  }
}

/// "Set email and send link": pick the account (pre-filled when matched), confirm the email, send.
class _ResolveSheet extends StatefulWidget {
  const _ResolveSheet({required this.request});
  final PasswordHelpRequest request;

  @override
  State<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends State<_ResolveSheet> {
  final _api = PasswordRecoveryApi();
  late final TextEditingController _email;
  final _remarks = TextEditingController();
  final _search = TextEditingController();
  int? _userId;
  String _accName = '';
  String _accSub = '';
  bool _searching = false;
  bool _showSearch = false;
  List<RecoveryAccount> _results = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _email = TextEditingController(text: r.requestedEmail);
    if (r.accountUserId != null) {
      _userId = r.accountUserId;
      _accName = r.accountDisplay;
      _accSub = [r.accountDepartment, r.accountMobile].where((e) => (e ?? '').isNotEmpty).join(' · ');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _remarks.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String q) async {
    setState(() => _searching = true);
    try {
      final list = await _api.searchAccounts(q);
      if (mounted) setState(() => _results = list);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _confirm() async {
    if (_userId == null) {
      showSnack(context, 'Please choose the account.', isError: true);
      return;
    }
    if (_email.text.trim().isEmpty) {
      showSnack(context, 'Please enter the email.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final msg = await _api.resolve(requestId: widget.request.requestId, userId: _userId!, email: _email.text.trim(), remarks: _remarks.text.trim());
      if (!mounted) return;
      showSnack(context, msg);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not reach the server.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set email and send reset link', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'Make sure this is really the person (name, department and mobile should match the account). The link goes to the email below, and whoever opens it can set the password.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Account', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userId == null ? 'No account chosen' : _accName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (_accSub.isNotEmpty) Text(_accSub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => setState(() => _showSearch = !_showSearch), child: const Text('Change')),
              ],
            ),
            if (_showSearch) ...[
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => _doSearch(v.trim()),
                decoration: const InputDecoration(hintText: 'Search name, username, mobile or email', prefixIcon: Icon(Icons.search)),
              ),
              if (_searching) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
              for (final a in _results)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.display, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([a.userName, a.subtitle].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12)),
                  onTap: () => setState(() {
                    _userId = a.userId;
                    _accName = a.display;
                    _accSub = a.subtitle;
                    _showSearch = false;
                  }),
                ),
            ],
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email to register')),
            const SizedBox(height: 12),
            TextField(controller: _remarks, decoration: const InputDecoration(labelText: 'Note (optional)')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _confirm,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save email & send link'),
            ),
          ],
        ),
      ),
    );
  }
}
