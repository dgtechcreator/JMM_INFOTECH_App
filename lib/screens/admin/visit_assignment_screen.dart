import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/places_service.dart';
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
  final _placesService = PlacesService();

  List<EmployeeSummary> _employees = [];
  List<VisitAssignment> _assignments = [];
  bool _loadingList = true;
  String? _listError;

  int? _selectedEmployeeId;
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController();
  DateTime? _scheduledDate;
  LatLng? _picked;
  bool _submitting = false;

  GoogleMapController? _mapController;
  List<PlacePrediction> _predictions = [];
  bool _searching = false;

  // The predictions dropdown used to be a Positioned overflow inside a Stack, which only escapes
  // *clipping* — it doesn't escape paint order. Everything below it in the outer ListView (the map,
  // Employee/Title/Notes fields) is a later sibling and still paints on top of it, so the dropdown
  // showed but was visually shredded by, and untappable under, the widgets after it. An OverlayEntry
  // paints in Flutter's overlay layer, which is always above the whole page, and CompositedTransformTarget/
  // Follower keeps it pinned under the search box (including while the ListView scrolls).
  final _searchFieldKey = GlobalKey();
  final _searchFieldLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEmployees();
    _loadAssignments();
  }

  @override
  void dispose() {
    _hideOverlay();
    _tabController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }
    final box = _searchFieldKey.currentContext!.findRenderObject() as RenderBox;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: box.size.width,
        child: CompositedTransformFollower(
          link: _searchFieldLink,
          showWhenUnlinked: false,
          offset: Offset(0, box.size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _predictions.length,
                itemBuilder: (context, i) {
                  final p = _predictions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 20),
                    title: Text(p.description, style: const TextStyle(fontSize: 13)),
                    onTap: () => _selectPrediction(p),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    if (_predictions.isEmpty) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
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

  Future<void> _onSearchChanged(String value) async {
    if (value.trim().length < 3) {
      setState(() => _predictions = []);
      _updateOverlay();
      return;
    }
    setState(() => _searching = true);
    try {
      final predictions = await _placesService.autocomplete(value);
      if (mounted) {
        setState(() { _predictions = predictions; _searching = false; });
        _updateOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        showSnack(context, 'Place search failed: $e', isError: true);
      }
    }
  }

  Future<void> _selectPrediction(PlacePrediction p) async {
    setState(() { _predictions = []; _searchController.text = p.description; });
    _hideOverlay();
    FocusScope.of(context).unfocus();
    try {
      final loc = await _placesService.placeDetails(p.placeId);
      if (loc == null) {
        if (mounted) showSnack(context, 'Could not load that place.', isError: true);
        return;
      }
      _movePin(LatLng(loc.lat, loc.lng), loc.address);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not load that place: $e', isError: true);
    }
  }

  Future<void> _onMapTap(LatLng point) async {
    _movePin(point, null);
    final address = await _placesService.reverseGeocode(point.latitude, point.longitude);
    if (address != null && mounted) setState(() => _addressController.text = address);
  }

  void _movePin(LatLng point, String? address) {
    setState(() {
      _picked = point;
      if (address != null) _addressController.text = address;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
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
      _searchController.clear();
      setState(() { _picked = null; _scheduledDate = null; _predictions = []; });
      _hideOverlay();
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: CompositedTransformTarget(
            link: _searchFieldLink,
            child: TextField(
              key: _searchFieldKey,
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search destination',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 260,
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(20.5937, 78.9629), zoom: 5),
            onMapCreated: (c) => _mapController = c,
            onTap: _onMapTap,
            markers: _picked != null ? {Marker(markerId: const MarkerId('destination'), position: _picked!)} : {},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            // This map sits inside the outer ListView, so its drag/pinch gestures compete with the
            // list's own vertical-scroll recognizer for the gesture arena — without claiming them
            // eagerly, one-finger pan and two-finger pinch-zoom on the map are dropped or scroll the
            // page instead. Standard fix for GoogleMap embedded in a scrollable parent.
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Search above, or tap on the map to drop the destination pin.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
