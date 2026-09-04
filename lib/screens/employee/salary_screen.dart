import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/salary_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'payslip_screen.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
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
      final records = await _service.getMySalaryList();
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salary & Payslips')),
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
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PayslipScreen(salaryId: r.salaryId))),
                          title: Text('${_months[r.payMonth]} ${r.payYear}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Due ₹${r.amountDue.toStringAsFixed(0)} · Paid ₹${r.amountPaid.toStringAsFixed(0)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(status: isPaid ? 'Paid' : 'Pending'),
                              const SizedBox(height: 4),
                              const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
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
