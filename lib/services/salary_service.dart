import '../core/api_client.dart';
import '../models/models.dart';

class SalaryService {
  final _client = ApiClient.instance;

  Future<List<SalaryRecord>> getMySalaryList() async {
    final res = await _client.get('/EmployeeApp/GetMySalaryList');
    return (res.data as List).cast<Map<String, dynamic>>().map(SalaryRecord.fromJson).toList();
  }

  Future<Map<String, dynamic>> getMyPayslip(int salaryId) async {
    final res = await _client.get('/EmployeeApp/GetMyPayslip', query: {'salaryId': salaryId});
    if (res.statusCode == 404) {
      throw ApiException('Payslip not found.', statusCode: 404);
    }
    final list = (res.data as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) {
      throw ApiException('Payslip not found.');
    }
    return list.first;
  }

  // ---- Admin ----

  Future<List<SalaryRecord>> getEmployeeSalaryList(int employeeId) async {
    final res = await _client.get('/EmployeeApp/GetEmployeeSalaryList', query: {'employeeId': employeeId});
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>().map(SalaryRecord.fromJson).toList();
  }

  Future<void> saveEmployeeSalary({
    required int employeeId,
    required int payMonth,
    required int payYear,
    required double amountDue,
    String? remarks,
  }) async {
    final res = await _client.post('/EmployeeApp/SaveEmployeeSalary', data: {
      'employeeId': employeeId,
      'payMonth': payMonth,
      'payYear': payYear,
      'amountDue': amountDue,
      'remarks': ?remarks,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not save salary.'));
    }
  }

  Future<void> markSalaryPaid(int salaryId, double amountPaid, String paymentMode) async {
    final res = await _client.post('/EmployeeApp/MarkSalaryPaid', data: {
      'salaryId': salaryId,
      'amountPaid': amountPaid,
      'paymentMode': paymentMode,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['status'] != 'success') {
      throw ApiException('Could not mark salary paid.');
    }
  }
}
