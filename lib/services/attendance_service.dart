import '../core/api_client.dart';
import '../models/models.dart';

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
    String? remarks,
  }) async {
    final res = await _client.post('/EmployeeApp/RegularizeAttendance', data: {
      'AttendanceID': attendanceId ?? 0,
      'EmployeeID': employeeId,
      'AttendanceDate': attendanceDate,
      'StatusID': statusId,
      'Remarks': ?remarks,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not update attendance.'));
    }
  }
}
