import '../core/api_client.dart';
import '../models/models.dart';

class ReimbursementService {
  final _client = ApiClient.instance;

  Future<List<ReimbursementRecord>> getMyReimbursementList() async {
    final res = await _client.get('/EmployeeApp/GetMyReimbursementList');
    return (res.data as List).cast<Map<String, dynamic>>().map(ReimbursementRecord.fromJson).toList();
  }

  Future<void> submitReimbursement({
    required String expenseDate,
    String? category,
    String? description,
    required double amount,
  }) async {
    final res = await _client.post('/EmployeeApp/SubmitReimbursement', data: {
      'ExpenseDate': expenseDate,
      'Category': ?category,
      'Description': ?description,
      'Amount': amount,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not submit reimbursement.'));
    }
  }

  /// Only ever succeeds server-side while the request is still Pending and actually belongs to the
  /// caller (USP_DeleteReimbursement enforces both, keyed off the token-resolved employee id — see
  /// EmployeeAppController.DeleteMyReimbursement) — lets an employee undo their own claim before an
  /// admin acts on it.
  Future<void> deleteReimbursement(int reimbursementId) async {
    final res = await _client.post('/EmployeeApp/DeleteMyReimbursement', data: {
      'reimbursementId': reimbursementId,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not delete this reimbursement.'));
    }
  }

  // ---- Admin ----

  Future<List<ReimbursementRecord>> getReimbursementList({int? employeeId}) async {
    final res = await _client.get('/EmployeeApp/GetReimbursementList', query: employeeId != null ? {'employeeId': employeeId} : null);
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>().map(ReimbursementRecord.fromJson).toList();
  }

  Future<void> actionReimbursement(int reimbursementId, String statusId, {String? remarks}) async {
    final res = await _client.post('/EmployeeApp/ActionReimbursement', data: {
      'reimbursementId': reimbursementId,
      'statusId': statusId,
      'remarks': remarks ?? '',
    });
    final data = res.data as Map<String, dynamic>;
    if (data['status'] != 'success') {
      throw ApiException('Could not update reimbursement.');
    }
  }

  Future<void> markReimbursementPaid(int reimbursementId, String paymentMode) async {
    final res = await _client.post('/EmployeeApp/MarkReimbursementPaid', data: {
      'reimbursementId': reimbursementId,
      'paymentMode': paymentMode,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['status'] != 'success') {
      throw ApiException('Could not mark reimbursement paid.');
    }
  }
}
