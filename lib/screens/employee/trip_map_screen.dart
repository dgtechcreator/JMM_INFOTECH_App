import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location_helper.dart';
import '../../models/models.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Map + Start/End Trip for one visit assignment. While a trip is InProgress, sends a location ping
/// every 5 minutes (mirrors the web My Visits tab's setInterval(sendPing, 5*60*1000) in
/// Views/Shared/_EmployeeProfileTabs.cshtml) — foreground only; this screen must stay open/app in
/// foreground for pings to keep going, same limitation as the web tab has while its page is open.
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key, required this.assignment});
  final VisitAssignment assignment;

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final _service = VisitService();
  final _mapController = MapController();

  int? _tripId;
  String _tripStatus = 'Pending';
  String _taskStatus = 'Pending';
  LatLng? _myLocation;
  Timer? _pingTimer;
  bool _busy = false;

  final _expenseDateController = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  bool _submittingExpense = false;

  LatLng get _destination => LatLng(widget.assignment.destinationLat, widget.assignment.destinationLng);

  @override
  void initState() {
    super.initState();
    _tripId = widget.assignment.activeTripId;
    _tripStatus = widget.assignment.statusId;
    if (_tripId != null) {
      _tripStatus = 'InProgress';
      _loadTripDetail();
      _startPingLoop();
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _categoryController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadTripDetail() async {
    if (_tripId == null) return;
    try {
      final trip = await _service.getTripDetail(_tripId!);
      if (trip != null && mounted) {
        setState(() => _taskStatus = trip.taskStatusId);
      }
    } catch (_) {}
  }

  void _startPingLoop() {
    _pingTimer?.cancel();
    _sendPing();
    _pingTimer = Timer.periodic(const Duration(minutes: 5), (_) => _sendPing());
  }

  Future<void> _sendPing() async {
    final (lat, lng) = await LocationHelper.tryGetLatLng();
    if (lat == null || lng == null || _tripId == null) return;
    if (mounted) setState(() => _myLocation = LatLng(lat, lng));
    try {
      await _service.saveTripPing(_tripId!, lat, lng);
    } catch (_) {}
  }

  Future<void> _startTrip() async {
    setState(() => _busy = true);
    try {
      final (lat, lng) = await LocationHelper.tryGetLatLng();
      final result = await _service.startTrip(widget.assignment.assignmentId, lat, lng);
      if (!mounted) return;
      setState(() {
        _tripId = result['tripId'] as int?;
        _tripStatus = 'InProgress';
        if (lat != null && lng != null) _myLocation = LatLng(lat, lng);
      });
      _startPingLoop();
      showSnack(context, 'Trip started.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this trip?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, end it')),
        ],
      ),
    );
    if (confirm != true || _tripId == null) return;

    setState(() => _busy = true);
    try {
      final (lat, lng) = await LocationHelper.tryGetLatLng();
      await _service.endTrip(_tripId!, lat, lng);
      _pingTimer?.cancel();
      if (!mounted) return;
      setState(() => _tripStatus = 'Completed');
      showSnack(context, 'Trip completed.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateTaskStatus(String status) async {
    if (_tripId == null) return;
    setState(() => _taskStatus = status);
    try {
      await _service.updateTripTaskStatus(_tripId!, status);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    }
  }

  Future<void> _submitExpense() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _tripId == null) {
      showSnack(context, 'Enter a valid amount.', isError: true);
      return;
    }
    setState(() => _submittingExpense = true);
    try {
      await _service.submitTripExpense(
        tripId: _tripId!,
        expenseDate: _expenseDateController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        amount: amount,
      );
      if (!mounted) return;
      showSnack(context, 'Expense submitted for reimbursement approval.');
      _categoryController.clear();
      _descriptionController.clear();
      _amountController.clear();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submittingExpense = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.assignment.title)),
      body: ListView(
        children: [
          SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _destination, initialZoom: 14),
              children: [
                TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c']),
                MarkerLayer(markers: [
                  Marker(point: _destination, width: 40, height: 40, child: const Icon(Icons.location_on, color: AppColors.danger, size: 36)),
                  if (_myLocation != null)
                    Marker(point: _myLocation!, width: 30, height: 30, child: const Icon(Icons.my_location, color: AppColors.success, size: 26)),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.assignment.destinationAddress != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(widget.assignment.destinationAddress!, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                if (_tripStatus != 'InProgress' && _tripStatus != 'Completed')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.navigation_outlined),
                    label: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Start Trip'),
                    onPressed: _busy ? null : _startTrip,
                  ),
                if (_tripStatus == 'InProgress') ...[
                  Row(
                    children: [
                      const Expanded(child: Text('Field work status', style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownButton<String>(
                        value: _taskStatus,
                        items: const [DropdownMenuItem(value: 'Pending', child: Text('Pending')), DropdownMenuItem(value: 'Done', child: Text('Done'))],
                        onChanged: (v) { if (v != null) _updateTaskStatus(v); },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.stop_circle_outlined, color: AppColors.danger),
                    label: Text(_busy ? 'Ending...' : 'End Trip', style: const TextStyle(color: AppColors.danger)),
                    onPressed: _busy ? null : _endTrip,
                  ),
                  const Divider(height: 32),
                  const Text('Add Expense for this Visit', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.sell_outlined))),
                  const SizedBox(height: 10),
                  TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_outlined)), maxLines: 2),
                  const SizedBox(height: 10),
                  TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _submittingExpense ? null : _submitExpense,
                    child: _submittingExpense
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add Expense'),
                  ),
                ],
                if (_tripStatus == 'Completed')
                  const Padding(padding: EdgeInsets.only(top: 12), child: Text('This visit is completed.', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
