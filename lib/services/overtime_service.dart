import '../core/api_client.dart';
import '../models/models.dart';

class OvertimeService {
  final _client = ApiClient.instance;

  Future<List<OvertimeLogRecord>> getMyOvertimeLogs() async {
    final res = await _client.get('/EmployeeApp/GetMyOvertimeLogs');
    return (res.data as List).cast<Map<String, dynamic>>().map(OvertimeLogRecord.fromJson).toList();
  }

  Future<void> logOvertime({required String otDate, required double hours, String? description}) async {
    final res = await _client.post('/EmployeeApp/LogOvertime', data: {
      'OTDate': otDate,
      'Hours': hours,
      if (description != null) 'Description': description,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not log overtime.'));
    }
  }

  // ---- Admin ----

  Future<List<OvertimeLogRecord>> getOvertimeAdminList({String? search, String? statusId, int? employeeId}) async {
    final res = await _client.get('/EmployeeApp/GetOvertimeAdminList', query: {
      'search': ?search,
      'statusId': ?statusId,
      'employeeId': ?employeeId,
    });
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>().map(OvertimeLogRecord.fromJson).toList();
  }

  Future<void> actionOvertimeLog(int otLogId, String statusId, {String? remarks}) async {
    final res = await _client.post('/EmployeeApp/ActionOvertimeLog', data: {
      'otLogId': otLogId,
      'statusId': statusId,
      'remarks': remarks ?? '',
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not update overtime log.'));
    }
  }
}
