import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/leave_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _service = LeaveService();

  List<LeaveTypeOption> _types = [];
  List<LeaveRecord> _history = [];
  bool _loadingHistory = true;
  bool _loadingTypes = true;
  String? _historyError;
  bool _showPendingOnly = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
    _loadHistory();
  }

  Future<void> _loadTypes() async {
    try {
      final types = await _service.getLeaveTypes();
      if (mounted) setState(() { _types = types; _loadingTypes = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTypes = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final history = await _service.getLeaveHistory();
      if (mounted) setState(() { _history = history; _loadingHistory = false; });
    } catch (e) {
      if (mounted) setState(() { _historyError = e.toString(); _loadingHistory = false; });
    }
  }

  Future<void> _cancel(LeaveRecord r) async {
    try {
      await _service.cancelLeave('${r.id}');
      if (mounted) showSnack(context, 'Leave cancelled.');
      _loadHistory();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  List<LeaveRecord> get _visibleHistory =>
      _showPendingOnly ? _history.where((r) => r.statusId.toLowerCase() == 'pending').toList() : _history;

  int get _pendingCount => _history.where((r) => r.statusId.toLowerCase() == 'pending').length;
  int get _approvedDaysThisYear => _history
      .where((r) => r.statusId.toLowerCase() == 'approved' && (DateTime.tryParse(r.fromDate)?.year ?? 0) == DateTime.now().year)
      .fold(0, (sum, r) => sum + (int.tryParse(r.totalDays) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      floatingActionButton: FloatingActionButton(onPressed: _openApplySheet, backgroundColor: AppColors.primary, child: const Icon(Icons.add, color: Colors.white)),
      body: _loadingHistory
          ? const LoadingView()
          : _historyError != null
              ? ErrorView(message: _historyError!, onRetry: _loadHistory)
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(child: StatCard(label: 'Pending Requests', value: '$_pendingCount', color: AppColors.warning, icon: Icons.hourglass_top_rounded)),
                          const SizedBox(width: 12),
                          Expanded(child: StatCard(label: 'Days Taken (${DateTime.now().year})', value: '$_approvedDaysThisYear', color: AppColors.success, icon: Icons.event_available)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            Expanded(child: _toggleTab('Pending', true)),
                            Expanded(child: _toggleTab('History', false)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_visibleHistory.isEmpty)
                        EmptyState(message: _showPendingOnly ? 'No pending leave requests.' : 'No leave records yet.', icon: Icons.event_busy_outlined)
                      else
                        ..._visibleHistory.map(_leaveCard),
                      const SizedBox(height: 72),
                    ],
                  ),
                ),
    );
  }

  Widget _toggleTab(String label, bool isPending) {
    final active = _showPendingOnly == isPending;
    return GestureDetector(
      onTap: () => setState(() => _showPendingOnly = isPending),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)] : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: active ? AppColors.primary : AppColors.textSecondary)),
      ),
    );
  }

  Widget _leaveCard(LeaveRecord r) {
    final from = DateTime.tryParse(r.fromDate);
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
                  if (from != null) Text(DateFormat('EEE').format(from), style: const TextStyle(fontSize: 11, color: AppColors.primary)),
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
                      Expanded(child: Text('${formatDate(r.fromDate)} → ${formatDate(r.toDate)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      StatusBadge(status: r.statusId),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${r.totalDays} day(s) · ${r.description}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if (r.statusId.toLowerCase() == 'pending') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: () => _cancel(r),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger), minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
                        child: const Text('Withdraw'),
                      ),
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
    LeaveTypeOption? selectedType;
    DateTime? fromDate;
    DateTime? toDate;
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
              int totalDays = 0;
              if (fromDate != null && toDate != null && !toDate!.isBefore(fromDate!)) {
                totalDays = toDate!.difference(fromDate!).inDays + 1;
              }

              Future<void> pickDate(bool isFrom) async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setSheetState(() => isFrom ? fromDate = picked : toDate = picked);
              }

              Future<void> submit() async {
                if (selectedType == null || fromDate == null || toDate == null || reasonController.text.trim().isEmpty) {
                  showSnack(context, 'Leave type, dates and reason are required.', isError: true);
                  return;
                }
                setSheetState(() => submitting = true);
                try {
                  await _service.applyLeave(
                    leaveTypeId: selectedType!.id,
                    fromDate: fromDate!.toIso8601String(),
                    toDate: toDate!.toIso8601String(),
                    totalDays: '$totalDays',
                    reason: reasonController.text.trim(),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(sheetContext);
                  showSnack(context, 'Leave request submitted.');
                  setState(() => _showPendingOnly = true);
                  _loadHistory();
                } catch (e) {
                  if (context.mounted) showSnack(context, e.toString(), isError: true);
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
                  const Text('Apply for Leave', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 16),
                  _loadingTypes
                      ? const LinearProgressIndicator()
                      : DropdownButtonFormField<LeaveTypeOption>(
                          initialValue: selectedType,
                          isExpanded: true,
                          hint: const Text('Select leave type'),
                          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t.name, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setSheetState(() => selectedType = v),
                        ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_outlined, size: 18),
                          onPressed: () => pickDate(true),
                          label: Text(fromDate == null ? 'From Date' : '${fromDate!.day}/${fromDate!.month}/${fromDate!.year}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_outlined, size: 18),
                          onPressed: () => pickDate(false),
                          label: Text(toDate == null ? 'To Date' : '${toDate!.day}/${toDate!.month}/${toDate!.year}'),
                        ),
                      ),
                    ],
                  ),
                  if (totalDays > 0) ...[
                    const SizedBox(height: 8),
                    Text('$totalDays day(s)', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 12),
                  TextField(controller: reasonController, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: submitting ? null : submit,
                    child: submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Request'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
