import '../core/api_client.dart';

/// One row of a user's login activity: a sign-in (mobile or website), a failed sign-in attempt, or a
/// security event (password/username/email changed, signed out remotely). Mirrors USP_GetLoginActivity.
class LoginActivityItem {
  LoginActivityItem({
    required this.activityId,
    required this.kind,
    required this.title,
    required this.eventOn,
    required this.source,
    required this.deviceName,
    required this.osVersion,
    required this.appVersion,
    required this.ipAddress,
    required this.status,
    required this.lastActiveOn,
    required this.logoutOn,
    required this.isCurrent,
    required this.sharedCount,
    required this.sharedWith,
    required this.details,
  });

  factory LoginActivityItem.fromJson(Map<String, dynamic> j) => LoginActivityItem(
        activityId: int.tryParse('${j['ActivityID'] ?? 0}') ?? 0,
        kind: j['Kind']?.toString() ?? '',
        title: j['Title']?.toString() ?? '',
        eventOn: j['EventOn']?.toString(),
        source: j['Source']?.toString() ?? '',
        deviceName: j['DeviceName']?.toString() ?? '',
        osVersion: j['OSVersion']?.toString() ?? '',
        appVersion: j['AppVersion']?.toString() ?? '',
        ipAddress: j['IPAddress']?.toString() ?? '',
        status: j['Status']?.toString() ?? '',
        lastActiveOn: j['LastActiveOn']?.toString(),
        logoutOn: j['LogoutOn']?.toString(),
        isCurrent: j['IsCurrent'] == true,
        sharedCount: int.tryParse('${j['SharedCount'] ?? 0}') ?? 0,
        sharedWith: j['SharedWith']?.toString(),
        details: j['Details']?.toString(),
      );

  final int activityId;

  /// Login | FailedLogin | PasswordChanged | UsernameChanged | EmailChanged | SessionRevoked
  final String kind;
  final String title;
  final String? eventOn;
  final String source; // Mobile | Web
  final String deviceName;
  final String osVersion;
  final String appVersion;
  final String ipAddress;

  /// Active | Logged out | Expired | Web session | Failed | Event
  final String status;
  final String? lastActiveOn;
  final String? logoutOn;

  /// This very phone (the session making the request).
  final bool isCurrent;

  /// How many OTHER accounts have signed in from the same physical device. Names are only ever sent to an
  /// admin ([sharedWith]); a person viewing their own activity just learns that it is shared.
  final int sharedCount;
  final String? sharedWith;
  final String? details;

  bool get isActiveMobileSession => kind == 'Login' && status == 'Active' && source == 'Mobile';
  bool get isFailedAttempt => kind == 'FailedLogin';
  bool get isEvent => status == 'Event';
}

class LoginActivitySummary {
  LoginActivitySummary({
    required this.activeSessions,
    required this.devices30d,
    required this.failedAttempts7d,
    required this.sharedDevices30d,
  });

  factory LoginActivitySummary.fromJson(Map<String, dynamic> j) => LoginActivitySummary(
        activeSessions: int.tryParse('${j['ActiveSessions'] ?? 0}') ?? 0,
        devices30d: int.tryParse('${j['Devices30d'] ?? 0}') ?? 0,
        failedAttempts7d: int.tryParse('${j['FailedAttempts7d'] ?? 0}') ?? 0,
        sharedDevices30d: int.tryParse('${j['SharedDevices30d'] ?? 0}') ?? 0,
      );

  final int activeSessions;
  final int devices30d;
  final int failedAttempts7d;
  final int sharedDevices30d;
}

/// Attendance punches with the device/IP each came from, plus an alert when it looks off (admin audit).
class PunchAuditRow {
  PunchAuditRow({
    required this.employeeName,
    required this.attendanceDate,
    required this.workMode,
    required this.punchInTime,
    required this.punchOutTime,
    required this.inDevice,
    required this.outDevice,
    required this.alertLevel,
    required this.alertText,
  });

  factory PunchAuditRow.fromJson(Map<String, dynamic> j) => PunchAuditRow(
        employeeName: j['EmployeeName']?.toString() ?? '',
        attendanceDate: j['AttendanceDate']?.toString(),
        workMode: j['WorkMode']?.toString() ?? 'Office',
        punchInTime: j['PunchInTime']?.toString(),
        punchOutTime: j['PunchOutTime']?.toString(),
        inDevice: (j['PunchInDeviceName'] ?? j['PunchInSource'])?.toString() ?? '-',
        outDevice: (j['PunchOutDeviceName'] ?? j['PunchOutSource'])?.toString() ?? '-',
        alertLevel: j['AlertLevel']?.toString() ?? '',
        alertText: j['DeviceAlert']?.toString() ?? '',
      );

  final String employeeName;
  final String? attendanceDate;
  final String workMode;
  final String? punchInTime;
  final String? punchOutTime;
  final String inDevice;
  final String outDevice;

  /// '' | 'info' | 'warn'
  final String alertLevel;
  final String alertText;
}

class SharedDeviceRow {
  SharedDeviceRow({required this.deviceName, required this.userCount, required this.users, required this.lastSeen});

  factory SharedDeviceRow.fromJson(Map<String, dynamic> j) => SharedDeviceRow(
        deviceName: (j['DeviceName'] ?? j['DeviceId'])?.toString() ?? '',
        userCount: int.tryParse('${j['UserCount'] ?? 0}') ?? 0,
        users: j['Users']?.toString() ?? '',
        lastSeen: j['LastSeen']?.toString(),
      );

  final String deviceName;
  final int userCount;
  final String users;
  final String? lastSeen;
}

class EmployeeLoginActivity {
  EmployeeLoginActivity({required this.summary, required this.items, this.message});
  final LoginActivitySummary? summary;
  final List<LoginActivityItem> items;
  final String? message;
}

class LoginActivityService {
  final _client = ApiClient.instance;

  // ---- My own activity (every signed-in user) ----

  Future<List<LoginActivityItem>> getMyLoginActivity() async {
    final res = await _client.get('/EmployeeApp/GetMyLoginActivity');
    return (res.data as List).cast<Map<String, dynamic>>().map(LoginActivityItem.fromJson).toList();
  }

  Future<LoginActivitySummary?> getMyLoginActivitySummary() async {
    final res = await _client.get('/EmployeeApp/GetMyLoginActivitySummary');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : LoginActivitySummary.fromJson(list.first);
  }

  /// Sign ONE other phone out. (Signing out this phone is just Logout.)
  Future<void> revokeSession(int activityId) async {
    final res = await _client.post('/EmployeeApp/RevokeMySession', data: {'activityId': activityId});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not sign that device out.'));
    }
  }

  Future<int> logoutOtherDevices() async {
    final res = await _client.post('/EmployeeApp/LogoutOtherDevices');
    final data = res.data as Map<String, dynamic>;
    return int.tryParse('${data['revoked'] ?? 0}') ?? 0;
  }

  // ---- Admin ----

  ApiException _forbidden(dynamic data) => ApiException(extractMessage(data, 'No admin access.'), statusCode: 403);

  Future<EmployeeLoginActivity> getEmployeeLoginActivity(int employeeId, {DateTime? from, DateTime? to}) async {
    final res = await _client.get('/EmployeeApp/GetEmployeeLoginActivity', query: {
      'employeeId': employeeId,
      if (from != null) 'fromDate': from.toIso8601String(),
      if (to != null) 'toDate': to.toIso8601String(),
    });
    if (res.statusCode == 403) throw _forbidden(res.data);
    final data = res.data as Map<String, dynamic>;
    final summary = data['summary'] is Map<String, dynamic> ? LoginActivitySummary.fromJson(data['summary'] as Map<String, dynamic>) : null;
    final items = ((data['items'] as List?) ?? const []).cast<Map<String, dynamic>>().map(LoginActivityItem.fromJson).toList();
    return EmployeeLoginActivity(summary: summary, items: items, message: data['message']?.toString());
  }

  /// Sign an employee's account out of every phone. Returns how many sessions were ended.
  Future<int> forceLogoutEmployee(int employeeId) async {
    final res = await _client.post('/EmployeeApp/ForceLogoutEmployee', data: {'employeeId': employeeId});
    if (res.statusCode == 403) throw _forbidden(res.data);
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not sign the account out.'));
    }
    return int.tryParse('${data['revoked'] ?? 0}') ?? 0;
  }

  Future<List<PunchAuditRow>> getPunchDeviceAudit({DateTime? from, DateTime? to, int? employeeId}) async {
    final res = await _client.get('/EmployeeApp/GetPunchDeviceAudit', query: {
      if (from != null) 'fromDate': from.toIso8601String(),
      if (to != null) 'toDate': to.toIso8601String(),
      'employeeId': ?employeeId,
    });
    if (res.statusCode == 403) throw _forbidden(res.data);
    return (res.data as List).cast<Map<String, dynamic>>().map(PunchAuditRow.fromJson).toList();
  }

  Future<List<SharedDeviceRow>> getSharedDeviceReport({int days = 30}) async {
    final res = await _client.get('/EmployeeApp/GetSharedDeviceReport', query: {'days': days});
    if (res.statusCode == 403) throw _forbidden(res.data);
    return (res.data as List).cast<Map<String, dynamic>>().map(SharedDeviceRow.fromJson).toList();
  }
}
