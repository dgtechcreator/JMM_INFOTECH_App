import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/api_client.dart';
import '../core/device_identity.dart';

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
      // Device details ride along as form fields: the server records which phone this sign-in came from
      // (Login Activity — "where is my account signed in" for the user, the shared-phone audit for admins).
      final device = await DeviceIdentity.load();
      final res = await _client.post('/EmployeeApp/Login', data: {
        'username': username,
        'password': password,
        'loginType': loginType,
        ...device.toFormFields(),
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

  /// Ties the stored session token to this phone. Called right after login AND on every start with a saved
  /// session — the latter links (and keeps fresh) sessions that were created before login tracking
  /// existed, which would otherwise be invisible in "My Login Activity". Best-effort.
  Future<void> registerSessionDevice(String loginType) async {
    try {
      final device = await DeviceIdentity.load();
      await _client.post('/EmployeeApp/RegisterSessionDevice', data: {'loginType': loginType, ...device.toFormFields()});
    } catch (_) {}
  }

  /// Tells the server this phone is signing out: the session token is revoked, the session is marked
  /// logged-out in Login Activity, and this phone stops receiving the account's push notifications (so the
  /// next person to sign in here — or nobody — doesn't keep getting them). Best-effort with a short
  /// timeout: signing out locally must never be blocked by a bad connection.
  Future<void> logoutFromServer() async {
    try {
      final device = await DeviceIdentity.load();
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
      await _client
          .post('/EmployeeApp/Logout', data: {'fcmToken': ?fcmToken, 'deviceId': device.deviceId})
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }
}
