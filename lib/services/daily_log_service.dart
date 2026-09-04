import '../core/api_client.dart';
import '../models/models.dart';

class DailyLogService {
  final _client = ApiClient.instance;

  Future<List<VisitLogRecord>> getMyVisitLogs() async {
    final res = await _client.get('/EmployeeApp/GetMyVisitLogs');
    return (res.data as List).cast<Map<String, dynamic>>().map(VisitLogRecord.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomerDropdown() async {
    final res = await _client.get('/EmployeeApp/GetCustomerDropdown');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getProjectDropdown() async {
    final res = await _client.get('/EmployeeApp/GetProjectDropdown');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveVisitLog({
    required String visitDate,
    required int customerId,
    required int projectId,
    required String agenda,
    String? duration,
  }) async {
    final res = await _client.post('/EmployeeApp/SaveMyVisitLog', data: {
      'VisitDate': visitDate,
      'Customer': customerId,
      'Project': projectId,
      'Agenda': agenda,
      'Duration': ?duration,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not save daily log.'));
    }
  }
}
