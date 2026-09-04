import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/reimbursement_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ReimbursementScreen extends StatefulWidget {
  const ReimbursementScreen({super.key});

  @override
  State<ReimbursementScreen> createState() => _ReimbursementScreenState();
}

class _ReimbursementScreenState extends State<ReimbursementScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = ReimbursementService();

  List<ReimbursementRecord> _records = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  DateTime _expenseDate = DateTime.now();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
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
    _categoryController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _service.getMyReimbursementList();
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      showSnack(context, 'Enter a valid amount.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _service.submitReimbursement(
        expenseDate: _expenseDate.toIso8601String(),
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        amount: amount,
      );
      if (!mounted) return;
      showSnack(context, 'Reimbursement request submitted.');
      _categoryController.clear();
      _descriptionController.clear();
      _amountController.clear();
      _tabController.animateTo(1);
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<ReimbursementRecord> get _filteredRecords {
    if (_filter == 'All') return _records;
    return _records.where((r) => r.statusId.toLowerCase() == _filter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reimbursement'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Add'), Tab(text: 'History')]),
      ),
      body: TabBarView(controller: _tabController, children: [_buildAddTab(), _buildHistoryTab()]),
    );
  }

  Widget _buildAddTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('New expense claim', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(formatDate(_expenseDate.toIso8601String())),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expenseDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _expenseDate = picked);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.sell_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_outlined)),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Claim'),
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Pending', 'Approved', 'Rejected', 'Paid'].map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(f), selected: selected, onSelected: (_) => setState(() => _filter = f)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (_filteredRecords.isEmpty)
            const EmptyState(message: 'No payments added.', icon: Icons.receipt_long_outlined)
          else
            ..._filteredRecords.map((r) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('₹${r.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            StatusBadge(status: r.statusId),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${r.category} · ${formatDate(r.expenseDate)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        if (r.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(r.description, style: const TextStyle(fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
