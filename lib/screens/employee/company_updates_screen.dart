import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/home_models.dart';
import '../../services/home_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// "View all" for Company Updates: notices, today's and upcoming holidays / events / birthdays / work
/// anniversaries, and what finished recently. Opened from the Home card and from a push notification.
/// Admins also get a "Post" button and Edit / Remove on every posted item (same rules as the web page).
class CompanyUpdatesScreen extends StatefulWidget {
  const CompanyUpdatesScreen({super.key});

  @override
  State<CompanyUpdatesScreen> createState() => _CompanyUpdatesScreenState();
}

class _CompanyUpdatesScreenState extends State<CompanyUpdatesScreen> {
  final _api = CompanyUpdatesApi();
  List<CompanyUpdate> _all = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';
  bool _markedRead = false;

  static const _filters = [
    ('All', 'All'),
    ('Notice', 'Notices'),
    ('Holiday', 'Holidays'),
    ('Event', 'Events'),
    ('Birthday', 'Birthdays'),
    ('Anniversary', 'Anniversaries'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isAdmin => context.read<Session>().loginType == 'Admin';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getFeed(upcomingDays: 120, pastDays: 30);
      if (!mounted) return;
      setState(() {
        _all = items;
        _loading = false;
      });
      // Opening the screen counts as having seen what is new. The NEW badges stay for this visit (the list was
      // fetched before the call) and are gone next time.
      if (!_markedRead) {
        _markedRead = true;
        try {
          await _api.markRead();
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markRead();
      if (!mounted) return;
      setState(() => _all = _all
          .map((u) => CompanyUpdate(
                itemKey: u.itemKey, type: u.type, sourceId: u.sourceId, title: u.title, description: u.description,
                eventDate: u.eventDate, endDate: u.endDate, startTime: u.startTime, location: u.location, daysAway: u.daysAway,
                bucket: u.bucket, isPinned: u.isPinned, isNew: false, postedBy: u.postedBy, postedOn: u.postedOn, department: u.department,
              ))
          .toList());
      showSnack(context, 'All updates marked as read.');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not reach the server.', isError: true);
    }
  }

  Future<void> _openForm([CompanyUpdate? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UpdateForm(existing: existing),
    );
    if (saved == true) {
      _markedRead = true; // our own post must not flash as "new" for us
      _load();
    }
  }

  Future<void> _remove(CompanyUpdate u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this update?'),
        content: Text('"${u.title}" will disappear for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete(u.sourceId);
      if (mounted) showSnack(context, 'Removed.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not reach the server.', isError: true);
    }
  }

  List<Widget> _section(String title, List<CompanyUpdate> items, bool admin) {
    if (items.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
      ),
      for (final u in items) _UpdateCard(update: u, canManage: admin && u.isPosted, onEdit: () => _openForm(u), onRemove: () => _remove(u)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final admin = _isAdmin;
    final items = _all.where((u) => _filter == 'All' || u.type == _filter).toList();
    final hasNew = _all.any((u) => u.isNew);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Updates'),
        actions: [
          if (hasNew) IconButton(tooltip: 'Mark all as read', icon: const Icon(Icons.done_all), onPressed: _markAllRead),
        ],
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Post'),
            )
          : null,
      body: _loading && _all.isEmpty
          ? const LoadingView()
          : _error != null && _all.isEmpty
              ? ErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        children: [
                          for (final f in _filters)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f.$2),
                                selected: _filter == f.$1,
                                showCheckmark: false,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(color: _filter == f.$1 ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                backgroundColor: AppColors.surface,
                                side: BorderSide(color: _filter == f.$1 ? AppColors.primary : AppColors.border),
                                onSelected: (_) => setState(() => _filter = f.$1),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: items.isEmpty
                            ? ListView(children: const [EmptyState(message: 'Nothing to show here yet.', icon: Icons.campaign_outlined)])
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                                children: [
                                  ..._section('Notices', items.where((u) => u.bucket == 'Notice').toList(), admin),
                                  ..._section('Today', items.where((u) => u.bucket == 'Today').toList(), admin),
                                  ..._section('Upcoming', items.where((u) => u.bucket == 'Upcoming').toList(), admin),
                                  ..._section('Recently', items.where((u) => u.bucket == 'Past').toList(), admin),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.update, required this.canManage, required this.onEdit, required this.onRemove});

  final CompanyUpdate update;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final u = update;
    final color = u.color;
    final pillColor = u.bucket == 'Today' ? AppColors.primary : (u.bucket == 'Past' ? AppColors.holiday : AppColors.info);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (u.isNew) Container(width: 4, color: AppColors.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
                      child: Icon(u.icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(u.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                              if (u.isPinned) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.push_pin, size: 14, color: AppColors.textSecondary)),
                              if (u.isNew)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                                  child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('${u.typeLabel} · ${u.subtitle(withWhen: false)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          if (u.isPosted && (u.description ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(u.description!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (u.bucket != 'Notice')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: pillColor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
                            child: Text(u.whenText, style: TextStyle(color: pillColor, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        if (canManage)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                            padding: EdgeInsets.zero,
                            onSelected: (v) => v == 'edit' ? onEdit() : onRemove(),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: AppColors.danger))),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Post / edit sheet (admin).
class _UpdateForm extends StatefulWidget {
  const _UpdateForm({this.existing});
  final CompanyUpdate? existing;

  @override
  State<_UpdateForm> createState() => _UpdateFormState();
}

class _UpdateFormState extends State<_UpdateForm> {
  final _api = CompanyUpdatesApi();
  late String _type;
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _time;
  late final TextEditingController _location;
  late DateTime _start;
  DateTime? _end;
  late bool _pinned;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? 'Notice';
    _title = TextEditingController(text: e?.title ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _time = TextEditingController(text: e?.startTime ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    final now = DateTime.now();
    _start = e?.eventDate ?? DateTime(now.year, now.month, now.day);
    _end = e?.endDate;
    _pinned = e?.isPinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _time.dispose();
    _location.dispose();
    super.dispose();
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _pick(bool isStart) async {
    final initial = isStart ? _start : (_end ?? _start);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(_start)) _end = null;
      } else {
        _end = picked.isBefore(_start) ? _start : picked;
      }
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showSnack(context, 'Please enter a title.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.save(
        updateId: widget.existing?.sourceId,
        type: _type,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        startDate: _start,
        endDate: _end,
        startTime: _type == 'Event' ? _time.text.trim() : '',
        location: _type == 'Event' ? _location.text.trim() : '',
        pinned: _type == 'Notice' && _pinned,
      );
      if (mounted) Navigator.pop(context, true);
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
    final editing = widget.existing != null;
    final startLabel = _type == 'Notice' ? 'Show from' : (_type == 'Holiday' ? 'Holiday date' : 'Event date');
    final endLabel = _type == 'Notice' ? 'Show until (optional)' : 'Last day (if more than one)';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(editing ? 'Edit update' : 'Post an update', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Notice', label: Text('Notice'), icon: Icon(Icons.campaign_outlined)),
                ButtonSegment(value: 'Holiday', label: Text('Holiday'), icon: Icon(Icons.beach_access_outlined)),
                ButtonSegment(value: 'Event', label: Text('Event'), icon: Icon(Icons.event_available_outlined)),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 14),
            TextField(controller: _title, maxLength: 200, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Title', counterText: '')),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 3, maxLength: 2000, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Details (optional)', counterText: '')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dateField(startLabel, _fmt(_start), () => _pick(true))),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateField(endLabel, _end == null ? 'Not set' : _fmt(_end!), () => _pick(false), onClear: _end == null ? null : () => setState(() => _end = null)),
                ),
              ],
            ),
            if (_type == 'Event') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: _time, maxLength: 20, decoration: const InputDecoration(labelText: 'Time (optional)', hintText: '4:00 PM', counterText: ''))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _location, maxLength: 200, decoration: const InputDecoration(labelText: 'Location (optional)', counterText: ''))),
                ],
              ),
            ],
            if (_type == 'Notice')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pinned,
                onChanged: (v) => setState(() => _pinned = v),
                title: const Text('Pin this notice', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Stays on top until you remove it', style: TextStyle(fontSize: 12)),
              ),
            if (!editing)
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 4),
                child: Text('Everyone will get a notification when you post this.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(editing ? 'Save changes' : 'Post'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, String value, VoidCallback onTap, {VoidCallback? onClear}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null ? const Icon(Icons.calendar_today_outlined, size: 18) : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClear),
        ),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
