import 'package:dio/dio.dart';
import '../core/api_client.dart';

class LoginResult {
  LoginResult({
    required this.token,
    required this.userId,
    required this.userName,
    required this.loginType,
    required this.employeeId,
    required this.hasAdminAccess,
    required this.photoUrl,
  });

  final String token;
  final int userId;
  final String userName;
  final String loginType;
  final int employeeId;
  final bool hasAdminAccess;
  final String? photoUrl;
}

class AuthService {
  final _client = ApiClient.instance;

  Future<LoginResult> login(String username, String password, String loginType) async {
    try {
      final res = await _client.post('/EmployeeApp/Login', data: {
        'username': username,
        'password': password,
        'loginType': loginType,
      });

      if (res.data is! Map<String, dynamic>) {
        throw ApiException('Invalid server response (${res.statusCode}). Please check API URL or server status.');
      }

      final data = res.data as Map<String, dynamic>;
      if (res.statusCode != 200 || data['status'] != '1') {
        throw ApiException(extractMessage(data, 'Login failed.'), statusCode: res.statusCode);
      }

      return LoginResult(
        token: data['token'] as String? ?? '',
        userId: data['userId'] as int? ?? 0,
        userName: data['userName'] as String? ?? '',
        loginType: data['loginType'] as String? ?? loginType,
        employeeId: data['employeeId'] as int? ?? 0,
        hasAdminAccess: data['hasAdminAccess'] as bool? ?? false,
        photoUrl: data['photoUrl'] as String?,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiException('Connection timed out. Please check your internet connection.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw ApiException('Unable to connect to server. Please check your network or server URL (${ApiConfig.baseUrl}).');
      } else if (e.response != null) {
        final msg = extractMessage(e.response?.data, 'Server error (${e.response?.statusCode})');
        throw ApiException(msg, statusCode: e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred.');
      }
    }
  }
}
