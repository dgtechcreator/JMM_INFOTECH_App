import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../services/task_service.dart';
import '../../widgets/common.dart';

/// Richer, dedicated Payroll workflow (base salary + that month's approved overtime auto-filled) —
/// parallel to the existing simple EmployeeSalaryScreen, which stays as-is. Talks to
/// /EmployeeApp/GetEmployeeOTSummary, /GetPayrollAdminList, /SavePayrollSalary (MVC.Web/Controllers/
/// API/EmployeeAppController.cs) — same procs/service methods PayrollController (web) uses.
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final _client = ApiClient.instance;
  final _taskService = TaskService();

  List<EmployeeSummary> _employees = [];
  int? _selectedEmployeeId;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  final _baseController = TextEditingController();
  final _otHoursController = TextEditingController(text: '0');
  final _otRateController = TextEditingController(text: '0');
  final _otherController = TextEditingController(text: '0');
  final _deductionsController = TextEditingController(text: '0');
  final _amountDueController = TextEditingController();
  final _remarksController = TextEditingController();
  bool _saving = false;

  List<Map<String, dynamic>> _teamRows = [];
  bool _loadingTeam = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadTeamPayroll();
  }

  @override
  void dispose() {
    _baseController.dispose();
    _otHoursController.dispose();
    _otRateController.dispose();
    _otherController.dispose();
    _deductionsController.dispose();
    _amountDueController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _taskService.getEmployeesDropdown();
      if (mounted) setState(() => _employees = employees);
    } catch (_) {}
  }

  Future<void> _loadTeamPayroll() async {
    setState(() => _loadingTeam = true);
    try {
      final res = await _client.get('/EmployeeApp/GetPayrollAdminList', query: {'month': _month, 'year': _year});
      if (mounted) setState(() { _teamRows = (res.data as List).cast<Map<String, dynamic>>(); _loadingTeam = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingTeam = false);
    }
  }

  void _recompute() {
    final base = double.tryParse(_baseController.text) ?? 0;
    final hours = double.tryParse(_otHoursController.text) ?? 0;
    final rate = double.tryParse(_otRateController.text) ?? 0;
    final other = double.tryParse(_otherController.text) ?? 0;
    final deductions = double.tryParse(_deductionsController.text) ?? 0;
    final otAmount = hours * rate;
    _amountDueController.text = (base + otAmount + other - deductions).toStringAsFixed(2);
  }

  Future<void> _loadOTSummary() async {
    if (_selectedEmployeeId == null) {
      showSnack(context, 'Select an employee first.', isError: true);
      return;
    }
    try {
      final res = await _client.get('/EmployeeApp/GetEmployeeOTSummary', query: {'employeeId': _selectedEmployeeId, 'month': _month, 'year': _year});
      final rows = (res.data as List).cast<Map<String, dynamic>>();
      if (rows.isNotEmpty) {
        final r = rows.first;
        _baseController.text = '${r['BaseSalary'] ?? 0}';
        _otHoursController.text = '${r['TotalOTHours'] ?? 0}';
        _otRateController.text = '${r['OTRate'] ?? 0}';
      }
      _recompute();
      setState(() {});
      _loadTeamPayroll();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _savePayroll() async {
    if (_selectedEmployeeId == null || _amountDueController.text.trim().isEmpty) {
      showSnack(context, 'Employee and amount due are required.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final otHours = double.tryParse(_otHoursController.text) ?? 0;
      final otRate = double.tryParse(_otRateController.text) ?? 0;
      await _client.post('/EmployeeApp/SavePayrollSalary', data: {
        'employeeId': _selectedEmployeeId,
        'payMonth': _month,
        'payYear': _year,
        'amountDue': double.tryParse(_amountDueController.text) ?? 0,
        'remarks': _remarksController.text.trim(),
        'baseSalary': double.tryParse(_baseController.text) ?? 0,
        'otHours': otHours,
        'otRate': otRate,
        'otAmount': otHours * otRate,
        'otherEarnings': double.tryParse(_otherController.text) ?? 0,
        'deductions': double.tryParse(_deductionsController.text) ?? 0,
      });
      if (!mounted) return;
      showSnack(context, 'Payroll saved.');
      _loadTeamPayroll();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            value: _selectedEmployeeId,
            decoration: const InputDecoration(labelText: 'Employee'),
            items: _employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
            onChanged: (v) => setState(() => _selectedEmployeeId = v),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _month,
                decoration: const InputDecoration(labelText: 'Month'),
                items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                onChanged: (v) => setState(() => _month = v ?? _month),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: '$_year',
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _year = int.tryParse(v) ?? _year,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadOTSummary, child: const Text('Load Base + Approved OT')),
          const SizedBox(height: 16),
          TextField(controller: _baseController, decoration: const InputDecoration(labelText: 'Base Salary', prefixText: '₹ '), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _recompute()),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _otHoursController, decoration: const InputDecoration(labelText: 'OT Hours'), readOnly: true)),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _otRateController, decoration: const InputDecoration(labelText: 'OT Rate/hr'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _recompute())),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _otherController, decoration: const InputDecoration(labelText: 'Other Earnings', prefixText: '₹ '), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _recompute()),
          const SizedBox(height: 10),
          TextField(controller: _deductionsController, decoration: const InputDecoration(labelText: 'Deductions', prefixText: '₹ '), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => _recompute()),
          const SizedBox(height: 10),
          TextField(controller: _amountDueController, decoration: const InputDecoration(labelText: 'Amount Due (final, editable)', prefixText: '₹ '), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          TextField(controller: _remarksController, decoration: const InputDecoration(labelText: 'Remarks')),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _savePayroll,
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Payroll'),
          ),
          const SizedBox(height: 24),
          Text('Team Payroll — $_month/$_year', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          if (_loadingTeam)
            const LoadingView()
          else if (_teamRows.isEmpty)
            const EmptyState(message: 'No employees found.', icon: Icons.groups_outlined)
          else
            ..._teamRows.map((r) {
              final due = (r['AmountDue'] as num?)?.toDouble();
              final paid = (r['AmountPaid'] as num?)?.toDouble() ?? 0;
              final balance = due != null ? due - paid : null;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${r['EmployeeName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${r['Department'] ?? ''} · Due ${due?.toStringAsFixed(0) ?? '-'}'),
                  trailing: due == null
                      ? const StatusBadge(status: 'Not generated')
                      : StatusBadge(status: (balance ?? 0) > 0 ? 'Pending' : 'Paid'),
                ),
              );
            }),
        ],
      ),
    );
  }
}
