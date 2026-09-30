import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/date_format.dart';
import '../core/location_helper.dart';
import '../services/wfh_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'swipe_button.dart';

/// "You're working from home today" — the start/end control for an APPROVED WFH day. Shown on the Home screen
/// and at the top of the Work From Home screen. Starting/ending writes the same attendance row the office
/// punch uses (marked WFH), so attendance, working hours and payroll all see the day; no geofence applies
/// (the phone's location is attached when available, for reference only).
class WfhDayCard extends StatefulWidget {
  const WfhDayCard({super.key, required this.today, required this.onChanged});

  final WfhToday today;

  /// Called after a successful start/end so the parent reloads its data.
  final VoidCallback onChanged;

  @override
  State<WfhDayCard> createState() => _WfhDayCardState();
}

class _WfhDayCardState extends State<WfhDayCard> {
  final _service = WfhService();
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // While the day is running, keep the "worked so far" line ticking.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && widget.today.working) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _punch(bool isIn) async {
    setState(() => _busy = true);
    try {
      final (lat, lng) = await LocationHelper.tryGetLatLng();
      await _service.punch(isIn: isIn, lat: lat, lng: lng);
      if (mounted) showSnack(context, isIn ? 'WFH day started. Have a productive day!' : 'WFH day ended. Good work!');
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Network error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _hm(int minutes) => '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';

  String _workedSoFar() {
    final start = DateTime.tryParse(widget.today.punchInTime ?? '')?.toLocal();
    if (start == null) return '';
    final minutes = DateTime.now().difference(start).inMinutes;
    return _hm(minutes < 0 ? 0 : minutes);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.today;
    final String status;
    if (t.notStarted) {
      status = 'Approved for today — slide to start your day so your attendance is marked.';
    } else if (t.working) {
      status = 'Started at ${formatTime(t.punchInTime)} · ${_workedSoFar()} so far';
    } else if (t.completed) {
      status = '${formatTime(t.punchInTime)} → ${formatTime(t.punchOutTime)} · ${_hm(t.workedMinutes)} worked';
    } else {
      status = 'You already punched in from the office today, so this WFH day isn\'t needed.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_work_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text('WORKING FROM HOME TODAY', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          Text(status, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
          if (t.notStarted || t.working) ...[
            const SizedBox(height: 16),
            SwipeToConfirmButton(
              key: ValueKey(t.workState),
              label: t.notStarted ? 'Slide to start WFH day' : 'Slide to end WFH day',
              color: Colors.white.withValues(alpha: 0.25),
              busy: _busy,
              onConfirm: () => _punch(t.notStarted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small pill for an attendance day: "WFH" (blue) — used in the attendance history.
class WorkModeChip extends StatelessWidget {
  const WorkModeChip({super.key, required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final wfh = mode == 'WFH';
    final color = wfh ? AppColors.info : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(wfh ? 'WFH' : 'Office', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
