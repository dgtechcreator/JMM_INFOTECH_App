import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Progress % is a straight-line/breadcrumb estimate (distance covered vs. total distance to
/// destination, computed server-side by USP_GetActiveTripsForTracking), not a routed ETA.
///
/// 2026-09-30 fix — "tapping refresh shows a map error, going back and reopening works":
/// the old screen swapped its whole body for a spinner on every manual refresh, which tore down the
/// GoogleMap platform view; the [GoogleMapController] field still pointed at that destroyed map, and the
/// very next `_fitBounds()` (run right after the new data arrived, before the NEW map had even been
/// created) called it -> exception -> caught by `_load`'s catch -> the whole screen turned into an error
/// view. Reopening the screen made a fresh controller, which is why that "fixed" it.
///
/// Now: the GoogleMap stays mounted for the screen's whole life (refresh only shows a thin progress bar),
/// every camera move is guarded (a failed animation can never become a screen-level error), and the camera
/// only auto-fits when the SET of active trips changes — not on every 30-second poll, which also used to
/// yank the map back while an admin was panning/zooming to look at one employee.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _service = VisitService();
  List<ActiveTrip> _trips = [];
  bool _initialLoading = true;
  bool _refreshing = false;
  String? _error; // blocking error view only while there is nothing to show yet
  DateTime? _lastUpdated;
  Timer? _refreshTimer;
  GoogleMapController? _mapController;
  bool _mapReady = false;
  String _lastFitKey = '';

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final controller = _mapController;
    _mapController = null;
    _mapReady = false;
    try {
      controller?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    if (!silent && !_initialLoading) setState(() => _refreshing = true);
    try {
      final trips = await _service.getActiveTripsForTracking();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _error = null;
        _initialLoading = false;
        _refreshing = false;
        _lastUpdated = DateTime.now();
      });
      // After the frame so the map (already mounted) has laid out with the new markers.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _refreshing = false;
        // A failed refresh must not throw away a map that is already showing good data.
        if (_trips.isEmpty) _error = e.toString();
      });
      if (!silent && _trips.isNotEmpty && mounted) {
        showSnack(context, "Couldn't refresh: ${e.toString()}", isError: true);
      }
    }
  }

  List<LatLng> _mapPoints() {
    final points = <LatLng>[];
    for (final t in _trips) {
      points.add(LatLng(t.destinationLat, t.destinationLng));
      if (t.latestLat != null && t.latestLng != null) points.add(LatLng(t.latestLat!, t.latestLng!));
    }
    return points;
  }

  String _tripKey() {
    final ids = _trips.map((t) => t.tripId).toList()..sort();
    return ids.join(',');
  }

  /// Fits the camera to every trip — once per change in the set of active trips (or when [force]d, e.g.
  /// the Recenter button). Never throws: a failed camera move is cosmetic, not an error state.
  Future<void> _fitCamera({bool force = false, bool retry = true}) async {
    final controller = _mapController;
    if (controller == null || !_mapReady || !mounted) return;
    final points = _mapPoints();
    if (points.isEmpty) return;

    final key = _tripKey();
    if (!force && key == _lastFitKey) return;

    try {
      var minLat = points.first.latitude, maxLat = points.first.latitude;
      var minLng = points.first.longitude, maxLng = points.first.longitude;
      for (final p in points) {
        minLat = p.latitude < minLat ? p.latitude : minLat;
        maxLat = p.latitude > maxLat ? p.latitude : maxLat;
        minLng = p.longitude < minLng ? p.longitude : minLng;
        maxLng = p.longitude > maxLng ? p.longitude : maxLng;
      }
      // Everything within ~100 m (or a single point): a bounds fit would zoom to the max — pick a sane zoom.
      final tiny = (maxLat - minLat).abs() < 0.001 && (maxLng - minLng).abs() < 0.001;
      if (tiny) {
        await controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), 15));
      } else {
        await controller.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
          56,
        ));
      }
      _lastFitKey = key;
    } catch (e) {
      // Typically "Map size can't be 0 — layout hasn't happened yet". Try once more shortly; otherwise
      // leave the camera where it is and try again on the next data change.
      if (kDebugMode) debugPrint('LiveTracking: camera fit skipped ($e)');
      if (retry && mounted) {
        Future.delayed(const Duration(milliseconds: 400), () => _fitCamera(force: force, retry: false));
      }
    }
  }

  String _updatedLabel() {
    final t = _lastUpdated;
    if (t == null) return '';
    final hh = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return 'Updated $hh:$mm:$ss ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          IconButton(
            tooltip: 'Fit all trips',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: _trips.isEmpty ? null : () => _fitCamera(force: true),
          ),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _refreshing ? null : () => _load()),
        ],
        bottom: _refreshing
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
            : null,
      ),
      body: _initialLoading
          ? const LoadingView()
          : (_error != null && _trips.isEmpty)
              ? ErrorView(message: _error!, onRetry: () {
                  setState(() {
                    _initialLoading = true;
                    _error = null;
                  });
                  _load();
                })
              : RefreshIndicator(
                  onRefresh: () async {
                    _refreshing = false; // pull-to-refresh has its own spinner
                    await _load();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 280,
                        child: Stack(
                          children: [
                            _buildMap(),
                            if (_trips.isEmpty)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    alignment: Alignment.center,
                                    child: const EmptyState(message: 'No active trips right now.', icon: Icons.navigation_outlined),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          _trips.isEmpty ? _updatedLabel() : '${_trips.length} active trip${_trips.length == 1 ? '' : 's'} · ${_updatedLabel()} · refreshes every 30 s',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                      ..._trips.map(_buildTripCard),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMap() {
    final markers = <Marker>{};
    for (final t in _trips) {
      markers.add(Marker(
        markerId: MarkerId('dest-${t.tripId}'),
        position: LatLng(t.destinationLat, t.destinationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: t.employeeName, snippet: t.title),
      ));
      if (t.latestLat != null && t.latestLng != null) {
        final alert = t.anomalyStatus != null && t.anomalyStatus!.isNotEmpty;
        markers.add(Marker(
          markerId: MarkerId('cur-${t.tripId}'),
          position: LatLng(t.latestLat!, t.latestLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(alert ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: t.employeeName,
            snippet: alert ? _anomalyLabel(t.anomalyStatus!) : (t.progressPct != null ? '${t.progressPct}% of the way' : 'In transit'),
          ),
        ));
      }
    }
    final points = _mapPoints();
    final center = points.isNotEmpty ? points.first : const LatLng(20.5937, 78.9629);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: points.length > 1 ? 6 : (points.isEmpty ? 4 : 12)),
      onMapCreated: (c) {
        _mapController = c;
        _mapReady = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera(force: true));
      },
      markers: markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      // The map sits inside a scrolling list: without this, dragging on the map scrolls the page instead of
      // panning the map.
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
    );
  }

  String _anomalyLabel(String status) {
    switch (status) {
      case 'LocationOff':
        return 'Location turned off';
      case 'NetworkOff':
        return 'Internet turned off';
      case 'Disconnected':
        return 'Not reachable';
      default:
        return status;
    }
  }

  Widget _buildTripCard(ActiveTrip t) {
    final alert = t.anomalyStatus != null && t.anomalyStatus!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      color: alert ? const Color(0xFFFFFBEB) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(t.employeeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(
                  t.latestCapturedOn != null ? 'Updated ${formatTime(t.latestCapturedOn)}' : 'No pings yet',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${t.title} · ${t.destinationAddress ?? ''}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (alert) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(_anomalyLabel(t.anomalyStatus!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            if (t.progressPct != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: t.progressPct! / 100, minHeight: 8, backgroundColor: AppColors.border),
              ),
              const SizedBox(height: 4),
              Text('${t.progressPct}% of the way', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ] else
              const Text('No location pings yet.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
