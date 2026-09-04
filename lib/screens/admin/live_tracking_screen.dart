import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/models.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Progress % is a straight-line/breadcrumb estimate (distance covered vs. total distance to
/// destination, computed server-side by USP_GetActiveTripsForTracking), not a routed ETA.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _service = VisitService();
  List<ActiveTrip> _trips = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final trips = await _service.getActiveTripsForTracking();
      if (mounted) setState(() { _trips = trips; _loading = false; });
      _fitBounds();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _fitBounds() {
    final controller = _mapController;
    final points = _mapPoints();
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 13));
      return;
    }
    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    controller.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      40,
    ));
  }

  List<LatLng> _mapPoints() {
    final points = <LatLng>[];
    for (final t in _trips) {
      points.add(LatLng(t.destinationLat, t.destinationLng));
      if (t.latestLat != null && t.latestLng != null) points.add(LatLng(t.latestLat!, t.latestLng!));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(appBar: null, body: LoadingView());

    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _trips.isEmpty
              ? const EmptyState(message: 'No active trips right now.', icon: Icons.navigation_outlined)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      SizedBox(height: 260, child: _buildMap()),
                      ..._trips.map(_buildTripCard),
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
        markers.add(Marker(
          markerId: MarkerId('cur-${t.tripId}'),
          position: LatLng(t.latestLat!, t.latestLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: t.employeeName, snippet: t.progressPct != null ? '${t.progressPct}% of the way' : 'In transit'),
        ));
      }
    }
    final points = _mapPoints();
    final center = points.isNotEmpty ? points.first : const LatLng(20.5937, 78.9629);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: points.length > 1 ? 6 : 12),
      onMapCreated: (c) { _mapController = c; _fitBounds(); },
      markers: markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
    );
  }

  Widget _buildTripCard(ActiveTrip t) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(t.employeeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(t.latestCapturedOn != null ? 'Updated' : 'No pings yet', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 4),
            Text('${t.title} · ${t.destinationAddress ?? ''}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
