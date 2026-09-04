import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/visit_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'trip_map_screen.dart';

class MyVisitsScreen extends StatefulWidget {
  const MyVisitsScreen({super.key});

  @override
  State<MyVisitsScreen> createState() => _MyVisitsScreenState();
}

class _MyVisitsScreenState extends State<MyVisitsScreen> {
  final _service = VisitService();
  List<VisitAssignment> _assignments = [];
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
      final rows = await _service.getMyVisitAssignments();
      if (mounted) setState(() { _assignments = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Visits')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _assignments.isEmpty
                  ? const EmptyState(message: 'No field visits assigned to you.', icon: Icons.map_outlined)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _assignments.length,
                        itemBuilder: (context, i) {
                          final a = _assignments[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: CircleIcon(icon: a.activeTripId != null ? Icons.navigation : Icons.place_outlined, color: statusColor(a.statusId)),
                              title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${a.destinationAddress ?? '${a.destinationLat}, ${a.destinationLng}'}\n${a.scheduledDate != null ? 'Scheduled: ${formatDate(a.scheduledDate)}' : ''}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ),
                              isThreeLine: true,
                              trailing: StatusBadge(status: a.statusId),
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => TripMapScreen(assignment: a)));
                                _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  const CircleIcon({super.key, required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
