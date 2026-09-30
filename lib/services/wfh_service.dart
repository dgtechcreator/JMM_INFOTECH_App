import '../core/api_client.dart';

/// One Work From Home request (mirrors USP_GetMyWfhRequests / USP_GetWfhAdminList).
class WfhRequest {
  WfhRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    required this.adminRemarks,
    required this.appliedOn,
    required this.daysWorked,
    required this.hoursWorked,
    required this.canCancel,
    required this.isToday,
  });

  factory WfhRequest.fromJson(Map<String, dynamic> j) {
    // The employee list returns MinutesWorked, the admin list HoursWorked — normalise to hours.
    final hours = j['HoursWorked'] != null
        ? double.tryParse('${j['HoursWorked']}') ?? 0
        : (int.tryParse('${j['MinutesWorked'] ?? 0}') ?? 0) / 60.0;
    return WfhRequest(
      id: int.tryParse('${j['WfhRequestID'] ?? 0}') ?? 0,
      employeeId: int.tryParse('${j['EmployeeID'] ?? 0}') ?? 0,
      employeeName: j['EmployeeName']?.toString() ?? '',
      fromDate: j['FromDate']?.toString() ?? '',
      toDate: j['ToDate']?.toString() ?? '',
      totalDays: int.tryParse('${j['TotalDays'] ?? 0}') ?? 0,
      reason: j['Reason']?.toString() ?? '',
      status: j['StatusID']?.toString() ?? 'Pending',
      adminRemarks: j['AdminRemarks']?.toString(),
      appliedOn: j['AppliedOn']?.toString(),
      daysWorked: int.tryParse('${j['DaysWorked'] ?? 0}') ?? 0,
      hoursWorked: hours,
      canCancel: j['CanCancel'] == true,
      isToday: j['IsToday'] == true,
    );
  }

  final int id;
  final int employeeId;
  final String employeeName;
  final String fromDate;
  final String toDate;
  final int totalDays;
  final String reason;

  /// Pending | Approved | Rejected | Cancelled
  final String status;
  final String? adminRemarks;
  final String? appliedOn;
  final int daysWorked;
  final double hoursWorked;
  final bool canCancel;
  final bool isToday;

  bool get isPending => status == 'Pending';
}

/// Where the employee is in TODAY's approved WFH day (USP_GetWfhToday). WorkState: NotStarted | Working |
/// Completed | PunchedInOffice.
class WfhToday {
  WfhToday({required this.requestId, required this.workState, required this.punchInTime, required this.punchOutTime, required this.workedMinutes, required this.reason});

  factory WfhToday.fromJson(Map<String, dynamic> j) => WfhToday(
        requestId: int.tryParse('${j['WfhRequestID'] ?? 0}') ?? 0,
        workState: j['WorkState']?.toString() ?? 'NotStarted',
        punchInTime: j['PunchInTime']?.toString(),
        punchOutTime: j['PunchOutTime']?.toString(),
        workedMinutes: int.tryParse('${j['WorkedMinutes'] ?? 0}') ?? 0,
        reason: j['Reason']?.toString() ?? '',
      );

  final int requestId;
  final String workState;
  final String? punchInTime;
  final String? punchOutTime;
  final int workedMinutes;
  final String reason;

  bool get notStarted => workState == 'NotStarted';
  bool get working => workState == 'Working';
  bool get completed => workState == 'Completed';
  bool get punchedInOffice => workState == 'PunchedInOffice';
}

/// Office vs WFH for the employee (USP_GetWfhSummary).
class WfhSummary {
  WfhSummary({
    required this.monthWfhDays,
    required this.monthOfficeDays,
    required this.monthWfhHours,
    required this.monthOfficeHours,
    required this.yearWfhDays,
    required this.yearOfficeDays,
    required this.pendingRequests,
    required this.upcomingApprovedDays,
    required this.monthRequestedDays,
    required this.monthCap,
  });

  factory WfhSummary.fromJson(Map<String, dynamic> j) => WfhSummary(
        monthWfhDays: int.tryParse('${j['MonthWfhDays'] ?? 0}') ?? 0,
        monthOfficeDays: int.tryParse('${j['MonthOfficeDays'] ?? 0}') ?? 0,
        monthWfhHours: double.tryParse('${j['MonthWfhHours'] ?? 0}') ?? 0,
        monthOfficeHours: double.tryParse('${j['MonthOfficeHours'] ?? 0}') ?? 0,
        yearWfhDays: int.tryParse('${j['YearWfhDays'] ?? 0}') ?? 0,
        yearOfficeDays: int.tryParse('${j['YearOfficeDays'] ?? 0}') ?? 0,
        pendingRequests: int.tryParse('${j['PendingRequests'] ?? 0}') ?? 0,
        upcomingApprovedDays: int.tryParse('${j['UpcomingApprovedDays'] ?? 0}') ?? 0,
        monthRequestedDays: int.tryParse('${j['MonthRequestedDays'] ?? 0}') ?? 0,
        monthCap: j['MonthCap'] != null ? int.tryParse('${j['MonthCap']}') : null,
      );

  final int monthWfhDays;
  final int monthOfficeDays;
  final double monthWfhHours;
  final double monthOfficeHours;
  final int yearWfhDays;
  final int yearOfficeDays;
  final int pendingRequests;
  final int upcomingApprovedDays;
  final int monthRequestedDays;

  /// Admin-configured monthly limit (null = none).
  final int? monthCap;
}

/// Admin "who is on WFH today" row (USP_GetWfhTodayBoard). WorkState: Not started | Working | Completed | In office.
class WfhBoardEntry {
  WfhBoardEntry({required this.requestId, required this.employeeName, required this.workState, required this.punchInTime, required this.punchOutTime, required this.workedMinutes, required this.reason});

  factory WfhBoardEntry.fromJson(Map<String, dynamic> j) => WfhBoardEntry(
        requestId: int.tryParse('${j['WfhRequestID'] ?? 0}') ?? 0,
        employeeName: j['EmployeeName']?.toString() ?? '',
        workState: j['WorkState']?.toString() ?? '',
        punchInTime: j['PunchInTime']?.toString(),
        punchOutTime: j['PunchOutTime']?.toString(),
        workedMinutes: int.tryParse('${j['WorkedMinutes'] ?? 0}') ?? 0,
        reason: j['Reason']?.toString() ?? '',
      );

  final int requestId;
  final String employeeName;
  final String workState;
  final String? punchInTime;
  final String? punchOutTime;
  final int workedMinutes;
  final String reason;
}

/// Admin monthly office-vs-WFH row (USP_GetWfhMonthlySummary).
class WfhMonthlyRow {
  WfhMonthlyRow({
    required this.employeeName,
    required this.officeDays,
    required this.wfhDays,
    required this.officeHours,
    required this.wfhHours,
    required this.approvedWfhDays,
    required this.pendingRequests,
    required this.leaveDays,
  });

  factory WfhMonthlyRow.fromJson(Map<String, dynamic> j) => WfhMonthlyRow(
        employeeName: j['EmployeeName']?.toString() ?? '',
        officeDays: int.tryParse('${j['OfficeDays'] ?? 0}') ?? 0,
        wfhDays: int.tryParse('${j['WfhDays'] ?? 0}') ?? 0,
        officeHours: double.tryParse('${j['OfficeHours'] ?? 0}') ?? 0,
        wfhHours: double.tryParse('${j['WfhHours'] ?? 0}') ?? 0,
        approvedWfhDays: int.tryParse('${j['ApprovedWfhDays'] ?? 0}') ?? 0,
        pendingRequests: int.tryParse('${j['PendingRequests'] ?? 0}') ?? 0,
        leaveDays: int.tryParse('${j['LeaveDays'] ?? 0}') ?? 0,
      );

  final String employeeName;
  final int officeDays;
  final int wfhDays;
  final double officeHours;
  final double wfhHours;
  final int approvedWfhDays;
  final int pendingRequests;
  final int leaveDays;

  int get totalDays => officeDays + wfhDays;
  double get wfhShare => totalDays == 0 ? 0 : wfhDays / totalDays;
}

class WfhSettings {
  WfhSettings({required this.autoRemindersEnabled, required this.startReminderTime, required this.endReminderTime, required this.maxDaysPerMonth});

  factory WfhSettings.fromJson(Map<String, dynamic> j) => WfhSettings(
        autoRemindersEnabled: j['AutoRemindersEnabled'] == true,
        startReminderTime: j['StartReminderTime']?.toString() ?? '11:30',
        endReminderTime: j['EndReminderTime']?.toString() ?? '20:00',
        maxDaysPerMonth: j['MaxDaysPerMonth'] != null ? int.tryParse('${j['MaxDaysPerMonth']}') : null,
      );

  final bool autoRemindersEnabled;
  final String startReminderTime;
  final String endReminderTime;
  final int? maxDaysPerMonth;
}

class WfhService {
  final _client = ApiClient.instance;

  // ---- Employee ----

  Future<List<WfhRequest>> getMyRequests() async {
    final res = await _client.get('/EmployeeApp/GetMyWfhRequests');
    return (res.data as List).cast<Map<String, dynamic>>().map(WfhRequest.fromJson).toList();
  }

  Future<WfhToday?> getToday() async {
    final res = await _client.get('/EmployeeApp/GetWfhToday');
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : WfhToday.fromJson(list.first);
  }

  Future<WfhSummary?> getSummary({int? month, int? year}) async {
    final res = await _client.get('/EmployeeApp/GetWfhSummary', query: {'month': ?month, 'year': ?year});
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : WfhSummary.fromJson(list.first);
  }

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> apply({required DateTime fromDate, required DateTime toDate, required String reason}) async {
    final res = await _client.post('/EmployeeApp/ApplyWfh', data: {'fromDate': _date(fromDate), 'toDate': _date(toDate), 'reason': reason});
    _requireSuccess(res.data, 'Could not submit the request.');
  }

  Future<void> cancel(int id) async {
    final res = await _client.post('/EmployeeApp/CancelWfh', data: {'id': id});
    _requireSuccess(res.data, 'Could not cancel the request.');
  }

  /// Employee-initiated reminder: nudges every admin about my own pending request.
  Future<void> remindAdmins(int id) async {
    final res = await _client.post('/EmployeeApp/SendMyWfhReminder', data: {'id': id});
    _requireSuccess(res.data, 'Could not send the reminder.');
  }

  /// Start (isIn = true) or end today's approved WFH day — writes the same attendance row the office punch
  /// uses, marked WFH, so attendance/hours/payroll all see it.
  Future<void> punch({required bool isIn, double? lat, double? lng}) async {
    final res = await _client.post(isIn ? '/EmployeeApp/WfhPunchIn' : '/EmployeeApp/WfhPunchOut', data: {'lat': ?lat, 'lng': ?lng});
    _requireSuccess(res.data, isIn ? 'Could not start your WFH day.' : 'Could not end your WFH day.');
  }

  // ---- Admin ----

  ApiException _forbidden(dynamic data) => ApiException(extractMessage(data, 'No admin access.'), statusCode: 403);

  Future<List<WfhRequest>> getAdminList({String? status, int? employeeId}) async {
    final res = await _client.get('/EmployeeApp/GetWfhAdminList', query: {
      if (status != null && status.isNotEmpty) 'statusId': status,
      'employeeId': ?employeeId,
    });
    if (res.statusCode == 403) throw _forbidden(res.data);
    return (res.data as List).cast<Map<String, dynamic>>().map(WfhRequest.fromJson).toList();
  }

  Future<void> action(int id, String status, {String? remarks}) async {
    final res = await _client.post('/EmployeeApp/ActionWfh', data: {'id': id, 'statusId': status, 'remarks': remarks ?? ''});
    if (res.statusCode == 403) throw _forbidden(res.data);
    _requireSuccess(res.data, 'Could not update the request.');
  }

  Future<List<WfhBoardEntry>> getTodayBoard() async {
    final res = await _client.get('/EmployeeApp/GetWfhTodayBoard');
    if (res.statusCode == 403) throw _forbidden(res.data);
    return (res.data as List).cast<Map<String, dynamic>>().map(WfhBoardEntry.fromJson).toList();
  }

  Future<List<WfhMonthlyRow>> getMonthlySummary({int? month, int? year}) async {
    final res = await _client.get('/EmployeeApp/GetWfhMonthlySummary', query: {'month': ?month, 'year': ?year});
    if (res.statusCode == 403) throw _forbidden(res.data);
    return (res.data as List).cast<Map<String, dynamic>>().map(WfhMonthlyRow.fromJson).toList();
  }

  /// Admin-initiated reminder: nudges the employee to start/end today's approved WFH day.
  Future<void> remindEmployee(int id) async {
    final res = await _client.post('/EmployeeApp/SendWfhReminder', data: {'id': id});
    if (res.statusCode == 403) throw _forbidden(res.data);
    _requireSuccess(res.data, 'Could not send the reminder.');
  }

  Future<WfhSettings?> getSettings() async {
    final res = await _client.get('/EmployeeApp/GetWfhSettings');
    if (res.statusCode == 403) throw _forbidden(res.data);
    final list = (res.data as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : WfhSettings.fromJson(list.first);
  }

  Future<void> saveSettings({required bool autoRemindersEnabled, required String startTime, required String endTime, int? maxDaysPerMonth}) async {
    final res = await _client.post('/EmployeeApp/SaveWfhSettings', data: {
      'autoRemindersEnabled': autoRemindersEnabled,
      'startTime': startTime,
      'endTime': endTime,
      'maxDaysPerMonth': ?maxDaysPerMonth,
    });
    if (res.statusCode == 403) throw _forbidden(res.data);
    _requireSuccess(res.data, 'Could not save the settings.');
  }

  void _requireSuccess(dynamic data, String fallback) {
    if (data is! Map || data['message'] != 'success') {
      throw ApiException(extractMessage(data, fallback));
    }
  }
}
