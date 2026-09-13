import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/document_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Letters issued to the signed-in employee (Offer Letter, Appointment Letter, Experience Certificate,
/// Relieving Letter, Salary Certificate, ...) — each opens as a real PDF in the device's own
/// browser/PDF viewer, since this app has no in-app PDF renderer (same approach as the payslip's
/// "Download PDF" button on PayslipScreen).
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _service = DocumentService();
  List<EmployeeDocumentRecord> _records = [];
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
      final records = await _service.getMyDocuments();
      if (mounted) setState(() { _records = records; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _open(EmployeeDocumentRecord doc) async {
    final uri = Uri.parse(_service.downloadUrl(doc.documentId));
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      showSnack(context, 'Could not open this document.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Documents')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _records.isEmpty
                  ? const EmptyState(message: 'No documents issued yet.', icon: Icons.description_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _records.length,
                        itemBuilder: (context, i) {
                          final d = _records[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () => _open(d),
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primarySoft,
                                child: Icon(Icons.description_outlined, color: AppColors.primary),
                              ),
                              title: Text(d.documentTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${d.templateName} · ${formatDate(d.documentDate)}'),
                              trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
