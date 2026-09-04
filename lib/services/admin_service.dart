import '../core/api_client.dart';

class AdminService {
  final _client = ApiClient.instance;

  Future<List<Map<String, dynamic>>> getEmployeeList({String? search}) async {
    final res = await _client.get('/EmployeeApp/GetEmployeeList', query: {'search': search ?? ''});
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>();
  }
}
