import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _service = AttendanceService();
  DateTime _focusedMonth = DateTime.now();
  List<AttendanceRecord> _records = [];
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
      final records = await _service.getMyAttendance(_focusedMonth.month, _focusedMonth.year);
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  AttendanceRecord? _recordFor(DateTime day) {
    for (final r in _records) {
      final parsed = _tryParseDdMmmYyyy(r.attendanceDate);
      if (parsed != null && isSameDay(parsed, day)) return r;
    }
    return null;
  }

  DateTime? _tryParseDdMmmYyyy(String s) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final parts = s.split(' ');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = months[parts[1]];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in _records) {
      counts[r.statusId] = (counts[r.statusId] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            SizedBox(width: 130, child: StatCard(label: 'Present', value: '${counts['Present'] ?? 0}', color: AppColors.present)),
                            const SizedBox(width: 10),
                            SizedBox(width: 130, child: StatCard(label: 'Half Day', value: '${counts['HalfDay'] ?? 0}', color: AppColors.halfDay)),
                            const SizedBox(width: 10),
                            SizedBox(width: 130, child: StatCard(label: 'On Leave', value: '${counts['OnLeave'] ?? 0}', color: AppColors.onLeave)),
                            const SizedBox(width: 10),
                            SizedBox(width: 130, child: StatCard(label: 'Absent', value: '${counts['Absent'] ?? 0}', color: AppColors.absent)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: TableCalendar(
                            firstDay: DateTime(2020, 1, 1),
                            lastDay: DateTime(2100, 1, 1),
                            focusedDay: _focusedMonth,
                            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                            calendarFormat: CalendarFormat.month,
                            availableGestures: AvailableGestures.horizontalSwipe,
                            onPageChanged: (day) {
                              setState(() => _focusedMonth = day);
                              _load();
                            },
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focusedDay) => _dayCell(day),
                              todayBuilder: (context, day, focusedDay) => _dayCell(day, isToday: true),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SectionHeader(title: 'History'),
                      if (_records.isEmpty)
                        const EmptyState(message: 'No attendance records this month.')
                      else
                        ..._records.map((r) => _historyTile(r)),
                    ],
                  ),
                ),
    );
  }

  Widget _dayCell(DateTime day, {bool isToday = false}) {
    final record = _recordFor(day);
    final color = record != null ? statusColor(record.statusId) : null;
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Text('${day.day}', style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: color != null ? FontWeight.w600 : FontWeight.normal)),
    );
  }

  Widget _historyTile(AttendanceRecord r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(r.attendanceDate),
        subtitle: Text('${formatTime(r.punchInTime)}  →  ${formatTime(r.punchOutTime)}  ·  ${r.workedMinutes} min'),
        trailing: StatusBadge(status: r.statusId),
      ),
    );
  }
}
