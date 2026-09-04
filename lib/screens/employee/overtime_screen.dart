import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/overtime_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class OvertimeScreen extends StatefulWidget {
  const OvertimeScreen({super.key});

  @override
  State<OvertimeScreen> createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = OvertimeService();

  List<OvertimeLogRecord> _records = [];
  bool _loading = true;
  String? _error;

  DateTime _otDate = DateTime.now();
  final _hoursController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hoursController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _service.getMyOvertimeLogs();
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _submit() async {
    final hours = double.tryParse(_hoursController.text.trim());
    if (hours == null || hours <= 0) {
      showSnack(context, 'Enter valid hours.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.logOvertime(
        otDate: _otDate.toIso8601String(),
        hours: hours,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, 'Overtime logged.');
      _hoursController.clear();
      _descriptionController.clear();
      _tabController.animateTo(1);
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overtime'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Log'), Tab(text: 'History')]),
      ),
      body: TabBarView(controller: _tabController, children: [_buildLogTab(), _buildHistoryTab()]),
    );
  }

  Widget _buildLogTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Log overtime / extra work', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(formatDate(_otDate.toIso8601String())),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _otDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _otDate = picked);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hoursController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Hours', prefixIcon: Icon(Icons.timer_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'What did you work on?', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_outlined)),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Log Overtime'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_records.isEmpty) return const EmptyState(message: 'No overtime logged yet.', icon: Icons.timer_outlined);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _records.length,
        itemBuilder: (context, i) {
          final r = _records[i];
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
                      Text('${r.hours} hrs', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      StatusBadge(status: r.statusId),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(formatDate(r.otDate), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  if ((r.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(r.description!, style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
