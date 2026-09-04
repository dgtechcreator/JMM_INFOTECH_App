import '../core/api_client.dart';
import '../models/models.dart';

class LeaveService {
  final _client = ApiClient.instance;

  Future<List<LeaveTypeOption>> getLeaveTypes() async {
    final res = await _client.get('/EmployeeApp/GetLeaveTypes');
    return (res.data as List).cast<Map<String, dynamic>>().map(LeaveTypeOption.fromJson).toList();
  }

  Future<List<LeaveRecord>> getLeaveHistory() async {
    final res = await _client.get('/EmployeeApp/GetLeaveHistory');
    return (res.data as List).cast<Map<String, dynamic>>().map(LeaveRecord.fromJson).toList();
  }

  Future<void> applyLeave({
    required int leaveTypeId,
    required String fromDate,
    required String toDate,
    required String totalDays,
    required String reason,
  }) async {
    final res = await _client.post('/EmployeeApp/ApplyLeave', data: {
      'LeaveTypeID': leaveTypeId,
      'FromDate': fromDate,
      'ToDate': toDate,
      'TotalDays': totalDays,
      'Reason': reason,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not submit leave request.'));
    }
  }

  Future<void> cancelLeave(String id) async {
    final res = await _client.post('/EmployeeApp/CancelLeave', data: {'id': id});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != null && data['message'].toString().toLowerCase().contains('error')) {
      throw ApiException(extractMessage(data, 'Could not cancel leave.'));
    }
  }

  // ---- Admin ----

  Future<List<Map<String, dynamic>>> getPendingLeaveList() async {
    final res = await _client.get('/EmployeeApp/GetPendingLeaveList');
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAllLeaveList() async {
    final res = await _client.get('/EmployeeApp/GetAllLeaveList');
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> approveLeave(int id) async {
    final res = await _client.post('/EmployeeApp/ApproveLeave', data: {'id': id});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not approve leave.'));
    }
  }

  Future<void> rejectLeave(int id) async {
    final res = await _client.post('/EmployeeApp/RejectLeave', data: {'id': id});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not reject leave.'));
    }
  }
}
