import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/date_format.dart';
import '../../services/wfh_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/wfh_day_card.dart';

/// Work From Home (employee): apply, see my requests and their status, start/end an approved WFH day, and
/// see how my month/year splits between the office and home. Web twin: Views/WorkFromHome/Index.cshtml —
/// both talk to the same WfhService on the server, so rules, notifications and reminders are identical.
class WfhScreen extends StatefulWidget {
  const WfhScreen({super.key});

  @override
  State<WfhScreen> createState() => _WfhScreenState();
}

class _WfhScreenState extends State<WfhScreen> {
  final _service = WfhService();
  List<WfhRequest> _requests = [];
  WfhToday? _today;
  WfhSummary? _summary;
  bool _loading = true;
  String? _error;

  // Which month the office-vs-home cards describe — the arrows above them walk back through past months so
  // the split can be tracked over time (the server computes any month from the attendance records).
  late DateTime _summaryMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _summaryLoading = false;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _summaryMonth.year == now.year && _summaryMonth.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _shiftMonth(int delta) async {
    final next = DateTime(_summaryMonth.year, _summaryMonth.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return; // no attendance in the future
    setState(() {
      _summaryMonth = next;
      _summaryLoading = true;
    });
    try {
      final s = await _service.getSummary(month: next.month, year: next.year);
      // Ignore a slow answer for a month the user has already moved away from.
      if (!mounted || _summaryMonth != next) return;
      setState(() {
        _summary = s;
        _summaryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _summaryLoading = false);
      showSnack(context, 'Could not load that month. Please try again.', isError: true);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getMyRequests(),
        _service.getToday(),
        _service.getSummary(month: _summaryMonth.month, year: _summaryMonth.year),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0] as List<WfhRequest>;
        _today = results[1] as WfhToday?;
        _summary = results[2] as WfhSummary?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _cancel(WfhRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text(r.isPending ? 'Your request will be withdrawn.' : 'This approved WFH will be cancelled and your admin will be told.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel request', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.cancel(r.id);
      if (mounted) showSnack(context, 'Request cancelled.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _remind(WfhRequest r) async {
    try {
      await _service.remindAdmins(r.id);
      if (mounted) showSnack(context, 'Reminder sent to admins.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  String _hm(double hours) {
    final minutes = (hours * 60).round();
    return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Work From Home')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _openApplySheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Apply', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_today != null) ...[
                        WfhDayCard(today: _today!, onChanged: _load),
                        const SizedBox(height: 16),
                      ],
                      if (_summary != null) _summaryCards(_summary!),
                      const SizedBox(height: 20),
                      const SectionHeader(title: 'My requests'),
                      if (_requests.isEmpty)
                        const EmptyState(message: 'You have not applied for Work From Home yet.\nTap Apply to request a day.', icon: Icons.home_work_outlined)
                      else
                        ..._requests.map(_requestCard),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryCards(WfhSummary s) {
    final shortMonth = DateFormat('MMM').format(_summaryMonth);
    final longMonth = DateFormat('MMMM yyyy').format(_summaryMonth);
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left),
              onPressed: _summaryLoading ? null : () => _shiftMonth(-1),
            ),
            Expanded(
              child: Center(
                child: Text(longMonth, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right),
              onPressed: (_summaryLoading || _isCurrentMonth) ? null : () => _shiftMonth(1),
            ),
          ],
        ),
        SizedBox(height: 3, child: _summaryLoading ? const LinearProgressIndicator() : null),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: StatCard(label: _isCurrentMonth ? 'WFH this month' : 'WFH in $shortMonth', value: '${s.monthWfhDays} day${s.monthWfhDays == 1 ? '' : 's'}', color: AppColors.info, icon: Icons.home_work_outlined)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(label: _isCurrentMonth ? 'Office this month' : 'Office in $shortMonth', value: '${s.monthOfficeDays} day${s.monthOfficeDays == 1 ? '' : 's'}', color: AppColors.primaryDark, icon: Icons.apartment_outlined)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: StatCard(label: '${_summaryMonth.year} WFH / Office', value: '${s.yearWfhDays} / ${s.yearOfficeDays}', color: AppColors.success, icon: Icons.insights_outlined)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(label: 'Pending requests', value: '${s.pendingRequests}', color: AppColors.warning, icon: Icons.hourglass_top_rounded)),
          ],
        ),
        if (s.monthWfhHours > 0 || s.monthOfficeHours > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Hours worked ${_isCurrentMonth ? 'this month' : 'in $longMonth'} — from home ${_hm(s.monthWfhHours)} · office ${_hm(s.monthOfficeHours)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        if (s.monthCap != null && _isCurrentMonth)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Monthly limit: ${s.monthRequestedDays} of ${s.monthCap} days requested', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
      ],
    );
  }

  Widget _requestCard(WfhRequest r) {
    final from = DateTime.tryParse(r.fromDate);
    final sameDay = r.fromDate == r.toDate;
    final canRemind = r.isPending;
    final canCancel = r.canCancel;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text(from != null ? '${from.day}' : '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary)),
                  if (from != null) Text(DateFormat('MMM').format(from), style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(sameDay ? formatDate(r.fromDate) : '${formatDate(r.fromDate)} → ${formatDate(r.toDate)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      StatusBadge(status: r.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${r.totalDays} day(s) · ${r.reason}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if (r.isToday)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.info)),
                    ),
                  if ((r.adminRemarks ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Admin: ${r.adminRemarks}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                    ),
                  if (r.daysWorked > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Worked from home ${r.daysWorked} day(s) · ${_hm(r.hoursWorked)}', style: const TextStyle(fontSize: 12, color: AppColors.success)),
                    ),
                  if (canRemind || canCancel) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (canRemind)
                          OutlinedButton.icon(
                            onPressed: () => _remind(r),
                            icon: const Icon(Icons.notifications_active_outlined, size: 16),
                            label: const Text('Remind Admin'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                          ),
                        if (canRemind && canCancel) const SizedBox(width: 8),
                        if (canCancel)
                          OutlinedButton(
                            onPressed: () => _cancel(r),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger), minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                            child: Text(r.isPending ? 'Withdraw' : 'Cancel'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openApplySheet() async {
    final today = DateTime.now();
    DateTime from = DateTime(today.year, today.month, today.day);
    DateTime to = from;
    final reasonController = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              // Mon-Sat days in the range (Sunday = weekly off) — same rule as the server, preview only.
              var workingDays = 0;
              for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
                if (d.weekday != DateTime.sunday) workingDays++;
              }

              Future<void> pick(bool isFrom) async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: isFrom ? from : to,
                  firstDate: isFrom ? DateTime(today.year, today.month, today.day) : from,
                  lastDate: DateTime(today.year, today.month, today.day).add(const Duration(days: 365)),
                );
                if (picked == null) return;
                setSheetState(() {
                  if (isFrom) {
                    from = picked;
                    if (to.isBefore(from)) to = from;
                  } else {
                    to = picked;
                  }
                });
              }

              Future<void> submit() async {
                if (reasonController.text.trim().length < 3) {
                  showSnack(context, 'Please enter a reason.', isError: true);
                  return;
                }
                if (workingDays == 0) {
                  showSnack(context, 'The selected dates are all Sundays (weekly off).', isError: true);
                  return;
                }
                setSheetState(() => submitting = true);
                try {
                  await _service.apply(fromDate: from, toDate: to, reason: reasonController.text.trim());
                  if (!context.mounted) return;
                  Navigator.pop(sheetContext);
                  showSnack(context, 'Request sent. Your admin has been notified.');
                  _load();
                } on ApiException catch (e) {
                  if (context.mounted) showSnack(context, e.message, isError: true);
                } catch (_) {
                  if (context.mounted) showSnack(context, 'Network error. Please try again.', isError: true);
                } finally {
                  setSheetState(() => submitting = false);
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Text('Apply for Work From Home', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Your admin will approve or reject it. Once approved, start and end your day from the app on the day.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.event_outlined, size: 18), onPressed: () => pick(true), label: Text('From  ${DateFormat('d MMM').format(from)}'))),
                      const SizedBox(width: 12),
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.event_outlined, size: 18), onPressed: () => pick(false), label: Text('To  ${DateFormat('d MMM').format(to)}'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('$workingDays working day(s) · Sundays not counted', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(controller: reasonController, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: submitting ? null : submit,
                    child: submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit Request'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    reasonController.dispose();
  }
}
