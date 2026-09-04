import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/task_service.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class VisitAssignmentScreen extends StatefulWidget {
  const VisitAssignmentScreen({super.key});

  @override
  State<VisitAssignmentScreen> createState() => _VisitAssignmentScreenState();
}

class _VisitAssignmentScreenState extends State<VisitAssignmentScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _visitService = VisitService();
  final _taskService = TaskService();

  List<EmployeeSummary> _employees = [];
  List<VisitAssignment> _assignments = [];
  bool _loadingList = true;
  String? _listError;

  int? _selectedEmployeeId;
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _scheduledDate;
  LatLng? _picked;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEmployees();
    _loadAssignments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await _taskService.getEmployeesDropdown();
      if (mounted) setState(() => _employees = employees);
    } catch (_) {}
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      final rows = await _visitService.getVisitAssignmentAdminList();
      if (mounted) setState(() { _assignments = rows; _loadingList = false; });
    } catch (e) {
      if (mounted) setState(() { _listError = e.toString(); _loadingList = false; });
    }
  }

  Future<void> _assign() async {
    if (_selectedEmployeeId == null || _titleController.text.trim().isEmpty || _picked == null) {
      showSnack(context, 'Employee, title and a map destination are required.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _visitService.saveVisitAssignment(
        employeeId: _selectedEmployeeId!,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        destinationLat: _picked!.latitude,
        destinationLng: _picked!.longitude,
        destinationAddress: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        scheduledDate: _scheduledDate?.toIso8601String(),
      );
      if (!mounted) return;
      showSnack(context, 'Visit assigned.');
      _titleController.clear();
      _notesController.clear();
      _addressController.clear();
      setState(() { _picked = null; _scheduledDate = null; });
      _tabController.animateTo(1);
      _loadAssignments();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(VisitAssignment a) async {
    try {
      await _visitService.deleteVisitAssignment(a.assignmentId);
      if (mounted) showSnack(context, 'Deleted.');
      _loadAssignments();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Visits'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Assign'), Tab(text: 'All Visits')]),
      ),
      body: TabBarView(controller: _tabController, children: [_buildAssignTab(), _buildListTab()]),
    );
  }

  Widget _buildAssignTab() {
    return ListView(
      children: [
        SizedBox(
          height: 260,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(20.5937, 78.9629),
              initialZoom: 5,
              onTap: (tapPosition, point) => setState(() => _picked = point),
            ),
            children: [
              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c']),
              if (_picked != null)
                MarkerLayer(markers: [
                  Marker(point: _picked!, width: 40, height: 40, child: const Icon(Icons.location_on, color: AppColors.danger, size: 36)),
                ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Tap on the map to drop the destination pin.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedEmployeeId,
                decoration: const InputDecoration(labelText: 'Employee'),
                items: _employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                onChanged: (v) => setState(() => _selectedEmployeeId = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Destination Address')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(_scheduledDate != null ? formatDate(_scheduledDate!.toIso8601String()) : 'Scheduled date (optional)'),
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setState(() => _scheduledDate = picked);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _assign,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Assign Visit'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTab() {
    if (_loadingList) return const LoadingView();
    if (_listError != null) return ErrorView(message: _listError!, onRetry: _loadAssignments);
    if (_assignments.isEmpty) return const EmptyState(message: 'No visits assigned yet.', icon: Icons.map_outlined);

    return RefreshIndicator(
      onRefresh: _loadAssignments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignments.length,
        itemBuilder: (context, i) {
          final a = _assignments[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${a.employeeName ?? ''}\n${a.destinationAddress ?? ''}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBadge(status: a.statusId),
                  IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _delete(a)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
