import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/location_helper.dart';
import '../../models/models.dart';
import '../../services/trip_tracking_service.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Map + Start/End Trip for one visit assignment. Location tracking itself (2026-09-27 rework) now runs
/// in TripTrackingService's background service — cached locally every ~20m of movement, flushed to the
/// server every 10 minutes, keeps running even if this screen (or the whole app) is closed. This screen
/// just starts/stops it and, while it's open, shows a live "you moved" marker plus a warning banner if
/// location or internet drops — the actual admin-notification for that is the background service's job
/// (see TripTrackingService's doc comment), this banner is purely so the employee sees it too and knows
/// to turn it back on.
class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key, required this.assignment});
  final VisitAssignment assignment;

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final _service = VisitService();
  GoogleMapController? _mapController;

  int? _tripId;
  String _tripStatus = 'Pending';
  String _taskStatus = 'Pending';
  LatLng? _myLocation;
  bool _busy = false;

  StreamSubscription<Position>? _uiPositionSub;
  StreamSubscription<ServiceStatus>? _locationWarningSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivityWarningSub;
  bool _locationOffWarning = false;
  bool _networkOffWarning = false;

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
      // The trip was already InProgress when this screen opened (e.g. reopened after backgrounding) —
      // the background service should already be tracking it from when it was started, this just makes
      // sure (harmless no-op if it's already running for this trip). Also re-checks permission here, not
      // just in _startTrip(): a reinstall/update resets Android's granted location permission back to
      // denied, and without this the background service would keep silently failing to start with no way
      // for the employee to notice — this is exactly what a reopen after a "Disconnected" flag should fix.
      _ensureTrackingPermissions().then((_) => TripTrackingService.startTracking(_tripId!));
      _startUiWatchers();
    }
  }

  @override
  void dispose() {
    _uiPositionSub?.cancel();
    _locationWarningSub?.cancel();
    _connectivityWarningSub?.cancel();
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

  // UI-only: moves the "me" marker on this screen's map and shows a warning banner while it's open. The
  // actual caching/batch-upload/admin-notification work happens in TripTrackingService's background
  // service regardless of whether this screen is even open — this is purely a nicer in-app experience
  // layered on top, not a second copy of the tracking logic.
  void _startUiWatchers() {
    _uiPositionSub?.cancel();
    _uiPositionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
    });

    _locationWarningSub?.cancel();
    _locationWarningSub = Geolocator.getServiceStatusStream().listen((status) {
      if (mounted) setState(() => _locationOffWarning = status != ServiceStatus.enabled);
    });

    _connectivityWarningSub?.cancel();
    _connectivityWarningSub = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _networkOffWarning = results.isEmpty || results.contains(ConnectivityResult.none));
    });
  }

  /// Explicitly asks for background ("Allow all the time") location, not just foreground — without this,
  /// the background service's location stream silently stops the moment the app leaves the foreground on
  /// Android 10+ (API 29+), which is exactly why live tracking, the batch sync, and the network/location
  /// off alerts never fired: nothing was requesting it, only the punch-in/out foreground check ran.
  Future<bool> _ensureTrackingPermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        showSnack(context, 'Location permission is required to start a trip. Please allow it and try again.', isError: true);
      }
      return false;
    }
    if (permission == LocationPermission.whileInUse) {
      // Re-requesting after the foreground grant is what triggers Android's "Allow all the time" upgrade
      // prompt on API 29; on API 30+ Android no longer offers it in-dialog and this call is a no-op, so we
      // warn below instead of silently tracking only while the screen is open.
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always && mounted) {
      showSnack(
        context,
        'Background location isn\'t fully allowed — tracking may pause once you leave the app. '
        'Open Settings > Apps > JMM InfoTech > Permissions > Location and choose "Allow all the time" for continuous tracking.',
        isError: true,
      );
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) showSnack(context, 'Turn on device location (GPS) to start the trip.', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _startTrip() async {
    setState(() => _busy = true);
    try {
      if (!await _ensureTrackingPermissions()) {
        setState(() => _busy = false);
        return;
      }
      final (lat, lng) = await LocationHelper.tryGetLatLng();
      final result = await _service.startTrip(widget.assignment.assignmentId, lat, lng);
      if (!mounted) return;
      setState(() {
        _tripId = result['tripId'] as int?;
        _tripStatus = 'InProgress';
        if (lat != null && lng != null) _myLocation = LatLng(lat, lng);
      });
      if (_tripId != null) {
        await TripTrackingService.startTracking(_tripId!);
        _startUiWatchers();
      }
      if (!mounted) return;
      showSnack(context, 'Trip started. Location tracking will keep running even if you close the app.');
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
      await TripTrackingService.stopTracking();
      await _uiPositionSub?.cancel();
      await _locationWarningSub?.cancel();
      await _connectivityWarningSub?.cancel();
      if (!mounted) return;
      setState(() {
        _tripStatus = 'Completed';
        _locationOffWarning = false;
        _networkOffWarning = false;
      });
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
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _destination, zoom: 14),
              onMapCreated: (c) => _mapController = c,
              markers: {
                Marker(markerId: const MarkerId('destination'), position: _destination, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
                if (_myLocation != null)
                  Marker(markerId: const MarkerId('me'), position: _myLocation!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
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
                if (_tripStatus == 'InProgress' && (_locationOffWarning || _networkOffWarning))
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.danger)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationOffWarning && _networkOffWarning
                                ? 'Location and internet are off. Please turn both back on — your admin has been notified.'
                                : _locationOffWarning
                                    ? 'Location is off. Please turn it back on — your admin has been notified.'
                                    : 'No internet connection. Please reconnect — your admin will be notified if this continues.',
                            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
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
