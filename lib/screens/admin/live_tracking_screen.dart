import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
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
    final markers = <Marker>[];
    final points = <LatLng>[];
    for (final t in _trips) {
      final dest = LatLng(t.destinationLat, t.destinationLng);
      markers.add(Marker(point: dest, width: 34, height: 34, child: const Icon(Icons.flag, color: AppColors.danger, size: 28)));
      points.add(dest);
      if (t.latestLat != null && t.latestLng != null) {
        final cur = LatLng(t.latestLat!, t.latestLng!);
        markers.add(Marker(point: cur, width: 30, height: 30, child: const Icon(Icons.person_pin_circle, color: AppColors.success, size: 30)));
        points.add(cur);
      }
    }
    final center = points.isNotEmpty ? points.first : const LatLng(20.5937, 78.9629);
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: points.length > 1 ? 6 : 12),
      children: [
        TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a', 'b', 'c']),
        MarkerLayer(markers: markers),
      ],
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
