import 'package:dio/dio.dart';

import '../core/api_client.dart';

/// Forgot password. Server side: PasswordRecoveryService (shared with the web login).
///   registered email -> emailed 6-digit OTP;  no email -> request to the admin, who sets the email and the
///   employee is emailed a reset link.
/// The three user calls run BEFORE login, so they carry no token.
class PasswordRecoveryApi {
  final _client = ApiClient.instance;

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> data) async {
    try {
      final res = await _client.post(path, data: data);
      if (res.data is! Map<String, dynamic>) {
        throw ApiException('Invalid server response (${res.statusCode}). Please try again.');
      }
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw ApiException('Connection timed out. Please check your internet connection.');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw ApiException('Unable to connect to the server. Please check your internet connection.');
      }
      throw ApiException(extractMessage(e.response?.data, 'Server error. Please try again.'));
    }
  }

  /// status: otp_sent | no_email | throttled | error
  Future<({String status, String? maskedEmail, String? message})> start(String identifier) async {
    final d = await _post('/EmployeeApp/ForgotPasswordStart', {'identifier': identifier});
    return (status: d['status']?.toString() ?? 'error', maskedEmail: d['maskedEmail'] as String?, message: d['message'] as String?);
  }

  /// Returns the success message; throws [ApiException] with the reason otherwise (wrong code, weak password...).
  Future<String> verifyAndReset({required String identifier, required String otp, required String newPassword, required String confirmPassword}) async {
    final d = await _post('/EmployeeApp/ForgotPasswordVerify', {
      'identifier': identifier,
      'otp': otp,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
    if (d['status'] != 'ok') throw ApiException(d['message']?.toString() ?? 'Could not reset the password.');
    return d['message']?.toString() ?? 'Your password has been reset.';
  }

  Future<String> requestAdminHelp({required String identifier, required String fullName, required String department, required String mobile, required String email}) async {
    final d = await _post('/EmployeeApp/ForgotPasswordRequestHelp', {
      'identifier': identifier,
      'fullName': fullName,
      'department': department,
      'mobile': mobile,
      'email': email,
    });
    if (d['status'] != 'ok') throw ApiException(d['message']?.toString() ?? 'Could not send the request.');
    return d['message']?.toString() ?? 'Your request has been sent to the administrator.';
  }

  // ---------------- admin ----------------

  Future<List<PasswordHelpRequest>> getRequests({String status = 'Pending'}) async {
    final res = await _client.get('/EmployeeApp/GetPasswordHelpRequests', query: {'status': status});
    if (res.statusCode == 403) throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    return (res.data as List).cast<Map<String, dynamic>>().map(PasswordHelpRequest.fromJson).toList();
  }

  Future<List<RecoveryAccount>> searchAccounts(String search) async {
    final res = await _client.get('/EmployeeApp/SearchRecoveryAccounts', query: {'search': search});
    if (res.statusCode == 403) throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    return (res.data as List).cast<Map<String, dynamic>>().map(RecoveryAccount.fromJson).toList();
  }

  /// Sets the email on the account, closes the request and mails the employee a reset link. Returns the message to show.
  Future<String> resolve({required int requestId, required int userId, required String email, String? remarks}) async {
    final res = await _client.post('/EmployeeApp/ResolvePasswordHelpRequest', data: {
      'requestId': requestId,
      'userId': userId,
      'email': email,
      'remarks': remarks ?? '',
    });
    return _adminResult(res, 'Could not save the email.');
  }

  Future<String> resendLink(int requestId) async {
    final res = await _client.post('/EmployeeApp/ResendPasswordLink', data: {'requestId': requestId});
    return _adminResult(res, 'Could not resend the link.');
  }

  Future<void> reject(int requestId, {String? remarks}) async {
    final res = await _client.post('/EmployeeApp/RejectPasswordHelpRequest', data: {'requestId': requestId, 'remarks': remarks ?? ''});
    if (res.statusCode == 403) throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    final d = res.data as Map<String, dynamic>;
    if (d['message'] != 'success') throw ApiException(extractMessage(d, 'Could not close the request.'));
  }

  String _adminResult(Response res, String fallback) {
    if (res.statusCode == 403) throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    final d = res.data as Map<String, dynamic>;
    if (d['message'] != 'success') throw ApiException(extractMessage(d, fallback));
    return d['detail']?.toString() ?? 'Done.';
  }
}

String? _s(dynamic v) => v?.toString();
bool _b(dynamic v) => v == true || v?.toString().toLowerCase() == 'true' || v?.toString() == '1';

class PasswordHelpRequest {
  PasswordHelpRequest({
    required this.requestId,
    required this.fullName,
    required this.department,
    required this.mobile,
    required this.requestedEmail,
    required this.identifier,
    required this.status,
    required this.createdOnText,
    required this.accountUserId,
    required this.accountName,
    required this.accountUserName,
    required this.accountDepartment,
    required this.accountMobile,
    required this.accountEmail,
    required this.nameMatches,
    required this.mobileMatches,
    required this.resolvedEmail,
    required this.resolvedOnText,
    required this.resolvedByName,
    required this.adminRemarks,
    required this.canResend,
  });

  factory PasswordHelpRequest.fromJson(Map<String, dynamic> j) => PasswordHelpRequest(
        requestId: int.tryParse('${j['RequestID']}') ?? 0,
        fullName: _s(j['FullName']) ?? '',
        department: _s(j['Department']),
        mobile: _s(j['Mobile']) ?? '',
        requestedEmail: _s(j['RequestedEmail']) ?? '',
        identifier: _s(j['Identifier']),
        status: _s(j['Status']) ?? 'Pending',
        createdOnText: _s(j['CreatedOnText']) ?? '',
        accountUserId: j['AccountUserID'] == null ? null : int.tryParse('${j['AccountUserID']}'),
        accountName: _s(j['AccountName']),
        accountUserName: _s(j['AccountUserName']),
        accountDepartment: _s(j['AccountDepartment']),
        accountMobile: _s(j['AccountMobile']),
        accountEmail: _s(j['AccountEmail']),
        nameMatches: _b(j['NameMatches']),
        mobileMatches: _b(j['MobileMatches']),
        resolvedEmail: _s(j['ResolvedEmail']),
        resolvedOnText: _s(j['ResolvedOnText']),
        resolvedByName: _s(j['ResolvedByName']),
        adminRemarks: _s(j['AdminRemarks']),
        canResend: _b(j['CanResend']),
      );

  final int requestId;
  final String fullName;
  final String? department;
  final String mobile;
  final String requestedEmail;
  final String? identifier;

  /// Pending | Resolved | Rejected
  final String status;
  final String createdOnText;
  final int? accountUserId;
  final String? accountName;
  final String? accountUserName;
  final String? accountDepartment;
  final String? accountMobile;
  final String? accountEmail;
  final bool nameMatches;
  final bool mobileMatches;
  final String? resolvedEmail;
  final String? resolvedOnText;
  final String? resolvedByName;
  final String? adminRemarks;
  final bool canResend;

  String get accountDisplay => (accountName ?? '').trim().isNotEmpty ? accountName!.trim() : (accountUserName ?? '');
}

class RecoveryAccount {
  RecoveryAccount({required this.userId, required this.userName, required this.fullName, this.department, this.mobile, this.email});

  factory RecoveryAccount.fromJson(Map<String, dynamic> j) => RecoveryAccount(
        userId: int.tryParse('${j['UserID']}') ?? 0,
        userName: _s(j['UserName']) ?? '',
        fullName: _s(j['FullName']) ?? '',
        department: _s(j['Department']),
        mobile: _s(j['Mobile']),
        email: _s(j['Email']),
      );

  final int userId;
  final String userName;
  final String fullName;
  final String? department;
  final String? mobile;
  final String? email;

  String get display => fullName.trim().isNotEmpty ? fullName.trim() : userName;
  String get subtitle => [department, mobile, email].where((e) => (e ?? '').isNotEmpty).join(' · ');
}
