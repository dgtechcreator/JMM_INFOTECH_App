import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'employee_profile_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _service = AdminService();
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

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
      final employees = await _service.getEmployeeList(search: _searchController.text.trim());
      if (mounted) setState(() { _employees = employees; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(hintText: 'Search employee...', prefixIcon: const Icon(Icons.search)),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _employees.isEmpty
                    ? const EmptyState(message: 'No employees found.', icon: Icons.groups_outlined)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _employees.length,
                          itemBuilder: (context, i) {
                            final e = _employees[i];
                            final id = int.tryParse('${e['ID']}') ?? 0;
                            final name = '${e['FirstName'] ?? ''} ${e['LastName'] ?? ''}'.trim();
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primarySoft,
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primaryDark)),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${e['Designation'] ?? ''} · ${e['Department'] ?? ''}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeProfileScreen(employeeId: id, employeeName: name))),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
