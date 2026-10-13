import 'package:flutter/material.dart';

import '../core/location_helper.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// "You haven't punched out" - shown to the employee when a day is still open past office end (or from an earlier
/// day). It is also where the "You haven't punched out" notification lands. The employee either says they are still
/// at the office (their position is checked against the office geofence by the server - inside = nothing changes,
/// outside = they are asked to mark their punch out) or tells us when they left (an admin is told about that).
///
/// Loads itself and stays empty when there is nothing to answer, or when the server doesn't have the endpoint yet
/// (older build): it must never get in the way of the screen that hosts it. [refreshToken] changes -> reload;
/// [onChanged] fires after the employee's answer changes the attendance (host refreshes its own numbers).
class MissedPunchOutCard extends StatefulWidget {
  const MissedPunchOutCard({super.key, this.refreshToken = 0, this.onChanged});

  final int refreshToken;
  final VoidCallback? onChanged;

  @override
  State<MissedPunchOutCard> createState() => _MissedPunchOutCardState();
}

class _MissedPunchOutCardState extends State<MissedPunchOutCard> {
  final _service = AttendanceService();
  MissedPunchOut? _missed;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MissedPunchOutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    try {
      final m = await _service.getMissedPunchOut();
      if (mounted) setState(() => _missed = m);
    } catch (_) {
      if (mounted) setState(() => _missed = null);
    }
  }

  Future<void> _stillAtOffice(MissedPunchOut m) async {
    setState(() => _busy = true);
    try {
      final (lat, lng) = await LocationHelper.tryGetLatLng();
      final result = await _service.confirmStillWorking(m.attendanceId, lat: lat, lng: lng);
      if (!mounted) return;
      if (result == 'success') {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Thanks'),
            content: const Text('Your location matches the office, so nothing was changed. We will ask again later if you have not punched out.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
        await _load();
      } else {
        final mark = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Not at the office?'),
            content: Text(result),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Close')),
              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Mark my punch out')),
            ],
          ),
        );
        if (mark == true && mounted) await _iLeft(m);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Network error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _iLeft(MissedPunchOut m) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: m.suggestedOut,
      helpText: 'When did you leave on ${m.dateText}?',
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _service.markMissedPunchOut(m.attendanceId, m.outTimeIso(picked.hour, picked.minute));
      if (!mounted) return;
      if (result == 'success') {
        showSnack(context, 'Punched out.');
        await _load();
        widget.onChanged?.call();
      } else {
        showSnack(context, result, isError: true);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Network error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _missed;
    // After "still at the office" the server snoozes it - stay quiet until it asks again.
    if (m == null || m.isSnoozed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  m.isPastDay
                      ? 'You punched in on ${m.dateText} at ${m.punchInText} but there is no punch out. When did you leave?'
                      : 'You punched in today at ${m.punchInText} and have not punched out yet. Are you still at the office?',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!m.isPastDay) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _stillAtOffice(m),
                    child: const Text("I'm still at office"),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _iLeft(m),
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("I've left - punch me out"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
