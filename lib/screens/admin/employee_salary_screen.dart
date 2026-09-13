import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/salary_service.dart';
import '../../theme/app_theme.dart';
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

  // USP_SaveEmployeeSalary upserts on (EmployeeID, PayMonth, PayYear) — saving again for a month that
  // already has a record UPDATES it in place rather than adding a new one. That's correct (one salary
  // row per employee per month), but silently overwriting whatever was there before reads as data loss
  // if the sheet isn't clear about it. So: default to the next unrecorded month, and whenever the chosen
  // month/year already has a record, show it plainly and switch the button to "Update".
  SalaryRecord? _existingRecord(int month, int year) {
    for (final r in _records) {
      if (r.payMonth == month && r.payYear == year) return r;
    }
    return null;
  }

  Future<void> _openAddSheet() async {
    final now = DateTime.now();
    int month = now.month;
    int year = now.year;
    if (_records.isNotEmpty) {
      final latest = _records.reduce((a, b) => (a.payYear * 12 + a.payMonth) >= (b.payYear * 12 + b.payMonth) ? a : b);
      month = latest.payMonth + 1;
      year = latest.payYear;
      if (month > 12) {
        month = 1;
        year++;
      }
    }

    final yearController = TextEditingController(text: '$year');
    final amountController = TextEditingController();
    final remarksController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final parsedYear = int.tryParse(yearController.text.trim());
            final existing = parsedYear == null ? null : _existingRecord(month, parsedYear);
            if (amountController.text.isEmpty && existing != null) {
              amountController.text = existing.amountDue.toStringAsFixed(0);
            }

            void onMonthYearChanged() {
              final y = int.tryParse(yearController.text.trim());
              final rec = y == null ? null : _existingRecord(month, y);
              setSheetState(() => amountController.text = rec != null ? rec.amountDue.toStringAsFixed(0) : '');
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing != null ? 'Update Salary' : 'Add Salary', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: month,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text(_months[m]))).toList(),
                      onChanged: (v) {
                        month = v ?? month;
                        onMonthYearChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Year'),
                      onChanged: (_) => onMonthYearChanged(),
                    ),
                  ),
                ]),
                if (existing != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'A record for ${_months[month]} $parsedYear already exists (Due ₹${existing.amountDue.toStringAsFixed(0)}, Paid ₹${existing.amountPaid.toStringAsFixed(0)}). Saving will update it, not add a new one.',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount Due', prefixText: '₹ ')),
                const SizedBox(height: 12),
                TextField(controller: remarksController, decoration: const InputDecoration(labelText: 'Remarks (optional)')),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final saveYear = int.tryParse(yearController.text.trim());
                    final amount = double.tryParse(amountController.text.trim());
                    if (saveYear == null || amount == null) {
                      showSnack(context, 'Enter a valid year and amount.', isError: true);
                      return;
                    }
                    try {
                      await _service.saveEmployeeSalary(employeeId: widget.employeeId, payMonth: month, payYear: saveYear, amountDue: amount, remarks: remarksController.text.trim());
                      // context.mounted is checked right before every use below — the analyzer still flags
                      // this nested-closure-inside-a-bottom-sheet-builder shape conservatively.
                      // ignore: use_build_context_synchronously
                      if (context.mounted) {
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context);
                        // ignore: use_build_context_synchronously
                        showSnack(context, existing != null ? 'Salary updated.' : 'Salary added.');
                        _load();
                      }
                    } catch (e) {
                      // ignore: use_build_context_synchronously
                      if (context.mounted) showSnack(context, e.toString(), isError: true);
                    }
                  },
                  child: Text(existing != null ? 'Update Salary' : 'Add Salary'),
                ),
              ],
            );
          },
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
      floatingActionButton: FloatingActionButton.extended(heroTag: null, onPressed: _openAddSheet, icon: const Icon(Icons.add), label: const Text('Add')),
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
                      final isPartial = !isPaid && r.amountPaid > 0;
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
                                  Expanded(child: Text('${_months[r.payMonth]} ${r.payYear}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                                  StatusBadge(status: isPaid ? 'Paid' : (isPartial ? 'Partial' : 'Pending')),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _AmountStat(label: 'Due', amount: r.amountDue)),
                                  Expanded(child: _AmountStat(label: 'Paid', amount: r.amountPaid)),
                                  Expanded(child: _AmountStat(label: 'Balance', amount: r.balance, color: isPaid ? AppColors.success : AppColors.danger)),
                                ],
                              ),
                              if (isPaid && (r.paymentDate != null || r.paymentMode != null)) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Paid on ${formatDate(r.paymentDate)}${r.paymentMode != null ? ' · ${r.paymentMode}' : ''}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                ),
                              ],
                              if (!isPaid) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(onPressed: () => _markPaid(r), child: const Text('Mark Paid')),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _AmountStat extends StatelessWidget {
  const _AmountStat({required this.label, required this.amount, this.color});
  final String label;
  final double amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}
