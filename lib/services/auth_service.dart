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
    final res = await _client.post('/EmployeeApp/Login', data: {
      'username': username,
      'password': password,
      'loginType': loginType,
    });

    final data = res.data as Map<String, dynamic>;
    if (res.statusCode != 200 || data['status'] != '1') {
      throw ApiException(extractMessage(data, 'Login failed.'), statusCode: res.statusCode);
    }

    return LoginResult(
      token: data['token'] as String,
      userId: data['userId'] as int,
      userName: data['userName'] as String? ?? '',
      loginType: data['loginType'] as String? ?? loginType,
      employeeId: data['employeeId'] as int? ?? 0,
      hasAdminAccess: data['hasAdminAccess'] as bool? ?? false,
      photoUrl: data['photoUrl'] as String?,
    );
  }
}
