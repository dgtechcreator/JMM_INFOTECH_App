import 'package:flutter/material.dart' show TimeOfDay;

import '../core/api_client.dart';
import '../models/models.dart';

/// An open attendance day (punched in, never punched out) that needs an answer - see MissedPunchOutService on the
/// server. The employee version comes from GetMissedPunchOut, the admin list from GetMissedPunchOuts.
class MissedPunchOut {
  MissedPunchOut({
    required this.attendanceId,
    required this.dateIso,
    required this.dateText,
    required this.punchInText,
    required this.punchInHm,
    required this.isPastDay,
    required this.isSnoozed,
    this.employeeName = '',
    this.workMode = 'Office',
    this.wasNotified = false,
    this.saidStillWorking = false,
  });

  factory MissedPunchOut.fromJson(Map<String, dynamic> j) => MissedPunchOut(
        attendanceId: int.tryParse('${j['AttendanceID']}') ?? 0,
        dateIso: '${j['AttendanceDateIso'] ?? ''}',
        dateText: '${j['AttendanceDateText'] ?? ''}',
        punchInText: '${j['PunchInText'] ?? ''}',
        punchInHm: '${j['PunchInHm'] ?? '10:00'}',
        isPastDay: '${j['IsPastDay']}' == '1' || '${j['IsPastDay']}'.toLowerCase() == 'true',
        isSnoozed: '${j['IsSnoozed']}' == '1' || '${j['IsSnoozed']}'.toLowerCase() == 'true',
        employeeName: '${j['EmployeeName'] ?? ''}',
        workMode: '${j['WorkMode'] ?? 'Office'}',
        wasNotified: '${j['WasNotified']}' == '1' || '${j['WasNotified']}'.toLowerCase() == 'true',
        saidStillWorking: '${j['SaidStillWorking']}' == '1' || '${j['SaidStillWorking']}'.toLowerCase() == 'true',
      );

  final int attendanceId;
  final String dateIso; // yyyy-MM-dd
  final String dateText;
  final String punchInText;
  final String punchInHm; // HH:mm, 24h
  final bool isPastDay;
  final bool isSnoozed;
  final String employeeName;
  final String workMode;
  final bool wasNotified;
  final bool saidStillWorking;

  /// A sensible starting time for the "when did you leave" picker: right now for today, otherwise
  /// punch-in + 8 hours (capped at 23:59) - the person corrects it.
  TimeOfDay get suggestedOut {
    if (!isPastDay) {
      final n = DateTime.now();
      return TimeOfDay(hour: n.hour, minute: n.minute);
    }
    final parts = punchInHm.split(':');
    final total = ((int.tryParse(parts.first) ?? 10) * 60 + (int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0) + 480).clamp(0, 1439);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  /// yyyy-MM-ddTHH:mm in the attendance day's own (local) date - the format the server parses.
  String outTimeIso(int hour, int minute) =>
      '${dateIso}T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class AttendanceService {
  final _client = ApiClient.instance;

  Future<AttendanceRecord?> getTodayStatus() async {
    final res = await _client.get('/EmployeeApp/GetTodayAttendanceStatus');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : AttendanceRecord.fromJson(list.first);
  }

  Future<Map<String, dynamic>> punchIn({double? lat, double? lng}) async {
    final res = await _client.post('/EmployeeApp/PunchIn', data: {
      'lat': ?lat,
      'lng': ?lng,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> punchOut({double? lat, double? lng}) async {
    final res = await _client.post('/EmployeeApp/PunchOut', data: {
      'lat': ?lat,
      'lng': ?lng,
    });
    return res.data as Map<String, dynamic>;
  }

  // ---- forgot to punch out ----

  /// The open day this employee still has to answer for, or null.
  Future<MissedPunchOut?> getMissedPunchOut() async {
    final res = await _client.get('/EmployeeApp/GetMissedPunchOut');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : MissedPunchOut.fromJson(list.first);
  }

  /// "I'm still at the office": the server checks the position against the office geofence.
  /// Returns 'success' or the message to show.
  Future<String> confirmStillWorking(int attendanceId, {double? lat, double? lng}) async {
    final res = await _client.post('/EmployeeApp/ConfirmStillWorking', data: {
      'attendanceId': attendanceId,
      'lat': ?lat,
      'lng': ?lng,
    });
    return ((res.data as Map<String, dynamic>)['message'] ?? 'Something went wrong.').toString();
  }

  /// "I left at ...": returns 'success' or the message to show.
  Future<String> markMissedPunchOut(int attendanceId, String outTimeIso) async {
    final res = await _client.post('/EmployeeApp/MarkMissedPunchOut', data: {
      'attendanceId': attendanceId,
      'outTime': outTimeIso,
    });
    return ((res.data as Map<String, dynamic>)['message'] ?? 'Something went wrong.').toString();
  }

  // Admin side.
  Future<List<MissedPunchOut>> getMissedPunchOuts() async {
    final res = await _client.get('/EmployeeApp/GetMissedPunchOuts');
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>().map(MissedPunchOut.fromJson).toList();
  }

  Future<String> adminMarkMissedPunchOut(int attendanceId, String outTimeIso) async {
    final res = await _client.post('/EmployeeApp/AdminMarkMissedPunchOut', data: {
      'attendanceId': attendanceId,
      'outTime': outTimeIso,
    });
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return ((res.data as Map<String, dynamic>)['message'] ?? 'Something went wrong.').toString();
  }

  Future<List<AttendanceRecord>> getMyAttendance(int month, int year) async {
    final res = await _client.get('/EmployeeApp/GetMyAttendance', query: {'month': month, 'year': year});
    return (res.data as List).cast<Map<String, dynamic>>().map(AttendanceRecord.fromJson).toList();
  }

  // ---- Admin ----

  Future<List<Map<String, dynamic>>> getTeamAttendanceList({String? search, DateTime? fromDate, DateTime? toDate}) async {
    final res = await _client.get('/EmployeeApp/GetTeamAttendanceList', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (fromDate != null) 'fromDate': fromDate.toIso8601String(),
      if (toDate != null) 'toDate': toDate.toIso8601String(),
    });
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<AttendanceRecord>> getEmployeeAttendance(int employeeId, int month, int year) async {
    final res = await _client.get('/EmployeeApp/GetEmployeeAttendance', query: {'employeeId': employeeId, 'month': month, 'year': year});
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>().map(AttendanceRecord.fromJson).toList();
  }

  Future<AdminDashboardSummary> getAdminDashboardSummary() async {
    final res = await _client.get('/EmployeeApp/GetAdminDashboardSummary');
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return AdminDashboardSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> regularizeAttendance({
    int? attendanceId,
    required int employeeId,
    required String attendanceDate,
    required String statusId,
    String? punchInTime,
    String? punchOutTime,
    String? remarks,
  }) async {
    final res = await _client.post('/EmployeeApp/RegularizeAttendance', data: {
      'AttendanceID': attendanceId ?? 0,
      'EmployeeID': employeeId,
      'AttendanceDate': attendanceDate,
      'StatusID': statusId,
      'PunchInTime': ?punchInTime,
      'PunchOutTime': ?punchOutTime,
      'Remarks': ?remarks,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not update attendance.'));
    }
  }
}
