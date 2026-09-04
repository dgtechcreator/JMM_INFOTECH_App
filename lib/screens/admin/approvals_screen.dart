import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/leave_service.dart';
import '../../services/overtime_service.dart';
import '../../services/reimbursement_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, this.initialTabIndex = 0});
  final int initialTabIndex;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Leave'), Tab(text: 'Reimbursement'), Tab(text: 'Overtime')]),
      ),
      body: TabBarView(controller: _tabController, children: const [_LeaveApprovalsTab(), _ReimbursementApprovalsTab(), _OvertimeApprovalsTab()]),
    );
  }
}

class _LeaveApprovalsTab extends StatefulWidget {
  const _LeaveApprovalsTab();
  @override
  State<_LeaveApprovalsTab> createState() => _LeaveApprovalsTabState();
}

class _LeaveApprovalsTabState extends State<_LeaveApprovalsTab> {
  final _service = LeaveService();
  List<Map<String, dynamic>> _rows = [];
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
      final rows = await _service.getPendingLeaveList();
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _act(int id, bool approve) async {
    try {
      if (approve) {
        await _service.approveLeave(id);
      } else {
        await _service.rejectLeave(id);
      }
      if (mounted) showSnack(context, approve ? 'Leave approved.' : 'Leave rejected.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const EmptyState(message: 'No pending leave requests.', icon: Icons.event_available_outlined);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final r = _rows[i];
          final id = int.tryParse('${r['Id']}') ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r['FullName'] ?? r['UserId'] ?? 'Employee'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${formatDate(r['FromDate']?.toString())} → ${formatDate(r['ToDate']?.toString())} · ${r['TotalDays'] ?? ''} day(s)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if (r['Reason'] != null) Text('${r['Reason']}', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => _act(id, false), child: const Text('Reject'))),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton(onPressed: () => _act(id, true), child: const Text('Approve'))),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReimbursementApprovalsTab extends StatefulWidget {
  const _ReimbursementApprovalsTab();
  @override
  State<_ReimbursementApprovalsTab> createState() => _ReimbursementApprovalsTabState();
}

class _ReimbursementApprovalsTabState extends State<_ReimbursementApprovalsTab> {
  final _service = ReimbursementService();
  List<ReimbursementRecord> _rows = [];
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
      final rows = await _service.getReimbursementList();
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _act(ReimbursementRecord r, String status) async {
    try {
      await _service.actionReimbursement(r.reimbursementId, status);
      if (mounted) showSnack(context, 'Reimbursement $status.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _markPaid(ReimbursementRecord r) async {
    final controller = TextEditingController(text: 'Bank Transfer');
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as paid'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Payment mode')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Confirm')),
        ],
      ),
    );
    if (mode == null) return;
    try {
      await _service.markReimbursementPaid(r.reimbursementId, mode);
      if (mounted) showSnack(context, 'Marked as paid.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const EmptyState(message: 'No reimbursement requests.', icon: Icons.receipt_long_outlined);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final r = _rows[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('₹${r.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${r.category} · ${formatDate(r.expenseDate)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StatusBadge(status: r.statusId),
                      if (r.statusId.toLowerCase() == 'pending')
                        Row(children: [
                          TextButton(onPressed: () => _act(r, 'Rejected'), child: const Text('Reject', style: TextStyle(color: AppColors.danger))),
                          ElevatedButton(onPressed: () => _act(r, 'Approved'), child: const Text('Approve')),
                        ])
                      else if (r.statusId.toLowerCase() == 'approved')
                        ElevatedButton(onPressed: () => _markPaid(r), child: const Text('Mark Paid')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OvertimeApprovalsTab extends StatefulWidget {
  const _OvertimeApprovalsTab();
  @override
  State<_OvertimeApprovalsTab> createState() => _OvertimeApprovalsTabState();
}

class _OvertimeApprovalsTabState extends State<_OvertimeApprovalsTab> {
  final _service = OvertimeService();
  List<OvertimeLogRecord> _rows = [];
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
      final rows = await _service.getOvertimeAdminList(statusId: 'Pending');
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _act(OvertimeLogRecord r, String status) async {
    try {
      await _service.actionOvertimeLog(r.otLogId, status);
      if (mounted) showSnack(context, 'Overtime $status.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const EmptyState(message: 'No pending overtime logs.', icon: Icons.timer_outlined);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final r = _rows[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('${r.hours} hrs', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(formatDate(r.otDate), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if ((r.description ?? '').isNotEmpty) Text(r.description!, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => _act(r, 'Rejected'), child: const Text('Reject'))),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton(onPressed: () => _act(r, 'Approved'), child: const Text('Approve'))),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
