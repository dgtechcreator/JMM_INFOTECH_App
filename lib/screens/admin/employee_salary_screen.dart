import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/salary_service.dart';
import '../../widgets/common.dart';

class EmployeeSalaryScreen extends StatefulWidget {
  const EmployeeSalaryScreen({super.key, required this.employeeId, required this.employeeName});
  final int employeeId;
  final String employeeName;

  @override
  State<EmployeeSalaryScreen> createState() => _EmployeeSalaryScreenState();
}

class _EmployeeSalaryScreenState extends State<EmployeeSalaryScreen> {
  final _service = SalaryService();
  List<SalaryRecord> _records = [];
  bool _loading = true;
  String? _error;

  static const _months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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
      final records = await _service.getEmployeeSalaryList(widget.employeeId);
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openAddSheet() async {
    final now = DateTime.now();
    final monthController = TextEditingController(text: '${now.month}');
    final yearController = TextEditingController(text: '${now.year}');
    final amountController = TextEditingController();
    final remarksController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add / Update Salary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextField(controller: monthController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Month (1-12)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: yearController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year'))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount Due', prefixText: '₹ ')),
            const SizedBox(height: 12),
            TextField(controller: remarksController, decoration: const InputDecoration(labelText: 'Remarks')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final month = int.tryParse(monthController.text.trim());
                final year = int.tryParse(yearController.text.trim());
                final amount = double.tryParse(amountController.text.trim());
                if (month == null || year == null || amount == null) {
                  showSnack(context, 'Fill month, year and amount.', isError: true);
                  return;
                }
                try {
                  await _service.saveEmployeeSalary(employeeId: widget.employeeId, payMonth: month, payYear: year, amountDue: amount, remarks: remarksController.text.trim());
                  // context.mounted is checked right before every use below — the analyzer still flags
                  // this nested-closure-inside-a-bottom-sheet-builder shape conservatively.
                  // ignore: use_build_context_synchronously
                  if (context.mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                    // ignore: use_build_context_synchronously
                    showSnack(context, 'Salary saved.');
                    _load();
                  }
                } catch (e) {
                  // ignore: use_build_context_synchronously
                  if (context.mounted) showSnack(context, e.toString(), isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markPaid(SalaryRecord r) async {
    final controller = TextEditingController(text: 'Bank Transfer');
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark ₹${r.balance.toStringAsFixed(2)} as paid'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Payment mode')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Confirm')),
        ],
      ),
    );
    if (mode == null) return;
    try {
      await _service.markSalaryPaid(r.salaryId, r.balance, mode);
      if (mounted) showSnack(context, 'Marked as paid.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.employeeName} — Salary')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openAddSheet, icon: const Icon(Icons.add), label: const Text('Add')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _records.isEmpty
              ? const EmptyState(message: 'No salary records yet.', icon: Icons.account_balance_wallet_outlined)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, i) {
                      final r = _records[i];
                      final isPaid = r.balance <= 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text('${_months[r.payMonth]} ${r.payYear}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Due ₹${r.amountDue.toStringAsFixed(0)} · Paid ₹${r.amountPaid.toStringAsFixed(0)}'),
                          trailing: isPaid
                              ? const StatusBadge(status: 'Paid')
                              : ElevatedButton(onPressed: () => _markPaid(r), child: const Text('Mark Paid')),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
