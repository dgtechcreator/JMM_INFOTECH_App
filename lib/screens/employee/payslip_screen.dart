import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/salary_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key, required this.salaryId});
  final int salaryId;

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final _service = SalaryService();
  Map<String, dynamic>? _payslip;
  bool _loading = true;
  String? _error;

  static const _months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

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
      final data = await _service.getMyPayslip(widget.salaryId);
      if (mounted) setState(() { _payslip = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _downloadPdf() async {
    final uri = Uri.parse(_service.payslipDownloadUrl(widget.salaryId));
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showSnack(context, 'Could not open the payslip PDF.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslip'),
        actions: [
          if (!_loading && _error == null) IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Download PDF', onPressed: _downloadPdf),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildPayslip(),
    );
  }

  Widget _buildPayslip() {
    final p = _payslip!;
    final month = int.tryParse('${p['PayMonth']}') ?? 0;
    final due = double.tryParse('${p['AmountDue']}') ?? 0;
    final paid = double.tryParse('${p['AmountPaid']}') ?? 0;
    final balance = double.tryParse('${p['Balance']}') ?? (due - paid);
    final isSettled = balance <= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('JMM Infotech Pvt. Ltd.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Payslip for ${_months[month]} ${p['PayYear']}', style: const TextStyle(color: AppColors.textSecondary)),
                  const Divider(height: 28),
                  _row('Employee', '${p['FirstName'] ?? ''} ${p['MiddleName'] ?? ''} ${p['LastName'] ?? ''}'),
                  _row('Department', '${p['Department'] ?? '-'}'),
                  _row('Designation', '${p['Designation'] ?? '-'}'),
                  if ('${p['BankAccountNo'] ?? ''}'.isNotEmpty)
                    _row('Bank', '${p['BankName'] ?? ''} (${p['BankAccountNo']})'),
                  const Divider(height: 28),
                  _row('Amount Due', '₹${due.toStringAsFixed(2)}'),
                  _row('Amount Paid', '₹${paid.toStringAsFixed(2)}'),
                  _row('Balance', '₹${balance.toStringAsFixed(2)} ${isSettled ? '(Settled)' : '(Due)'}',
                      valueColor: isSettled ? AppColors.success : AppColors.danger, bold: true),
                  if (p['PaymentDate'] != null) _row('Payment Date', '${p['PaymentDate']}'),
                  if (p['PaymentMode'] != null) _row('Payment Mode', '${p['PaymentMode']}'),
                  if (p['Remarks'] != null && '${p['Remarks']}'.isNotEmpty) _row('Remarks', '${p['Remarks']}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: valueColor)),
          ),
        ],
      ),
    );
  }
}
