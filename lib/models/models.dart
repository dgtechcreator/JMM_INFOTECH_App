/// Lightweight models for the /EmployeeApp/* API responses (MVC.Web/Controllers/API/EmployeeAppController.cs).
/// Field names below match the JSON keys the API actually returns (checked against the live DB while
/// building the backend, not guessed) — DataTable-sourced fields keep the C#/SQL casing (e.g.
/// PayMonth, StatusID); a few fields are therefore not camelCase for consistency with the API.
library;

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

double _asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String _asString(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v == null) return false;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1';
}

class AttendanceRecord {
  AttendanceRecord({
    required this.attendanceId,
    required this.attendanceDate,
    required this.punchInTime,
    required this.punchOutTime,
    required this.workedMinutes,
    required this.statusId,
    required this.remarks,
    required this.isRegularized,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        attendanceId: _asInt(j['AttendanceID']),
        attendanceDate: _asString(j['AttendanceDate']),
        punchInTime: j['PunchInTime'] as String?,
        punchOutTime: j['PunchOutTime'] as String?,
        workedMinutes: _asInt(j['WorkedMinutes']),
        statusId: _asString(j['StatusID']),
        remarks: j['Remarks'] as String?,
        isRegularized: _asBool(j['IsRegularized']),
      );

  final int attendanceId;
  final String attendanceDate;
  final String? punchInTime;
  final String? punchOutTime;
  final int workedMinutes;
  final String statusId;
  final String? remarks;
  final bool isRegularized;
}

class LeaveTypeOption {
  LeaveTypeOption({required this.id, required this.name});
  factory LeaveTypeOption.fromJson(Map<String, dynamic> j) =>
      LeaveTypeOption(id: _asInt(j['ID']), name: _asString(j['Name']));
  final int id;
  final String name;
}

class LeaveRecord {
  LeaveRecord({
    required this.id,
    required this.leaveTypeId,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.description,
    required this.statusId,
  });

  factory LeaveRecord.fromJson(Map<String, dynamic> j) => LeaveRecord(
        id: _asInt(j['Id']),
        leaveTypeId: _asString(j['LeaveTypeID']),
        fromDate: _asString(j['FromDate']),
        toDate: _asString(j['ToDate']),
        totalDays: _asString(j['TotalDays']),
        description: _asString(j['Descriptions']),
        statusId: _asString(j['StatusID'], 'Pending'),
      );

  final int id;
  final String leaveTypeId;
  final String fromDate;
  final String toDate;
  final String totalDays;
  final String description;
  final String statusId;
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.statusId,
    required this.projectName,
    required this.documentPath,
  });

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: _asInt(j['ID']),
        title: _asString(j['Title']),
        dueDate: _asString(j['DueDate']),
        priority: _asString(j['TaskPriority']),
        status: _asString(j['Status']),
        statusId: _asInt(j['StatusID']),
        projectName: _asString(j['ProjectName']),
        documentPath: j['DocumentPath'] as String?,
      );

  final int id;
  final String title;
  final String dueDate;
  final String priority;
  final String status;
  final int statusId;
  final String projectName;
  final String? documentPath;
}

class TaskStatusOption {
  TaskStatusOption({required this.id, required this.name});
  factory TaskStatusOption.fromJson(Map<String, dynamic> j) =>
      TaskStatusOption(id: _asInt(j['ID']), name: _asString(j['TaskStatus']));
  final int id;
  final String name;
}

class VisitLogRecord {
  VisitLogRecord({
    required this.id,
    required this.agenda,
    required this.visitDate,
    required this.duration,
    required this.customerName,
    required this.projectName,
  });

  factory VisitLogRecord.fromJson(Map<String, dynamic> j) => VisitLogRecord(
        id: _asInt(j['ID']),
        agenda: _asString(j['Agenda']),
        visitDate: _asString(j['Visitdate']),
        duration: _asString(j['Duration']),
        customerName: _asString(j['CustomerName']),
        projectName: _asString(j['ProjectName']),
      );

  final int id;
  final String agenda;
  final String visitDate;
  final String duration;
  final String customerName;
  final String projectName;
}

class ReimbursementRecord {
  ReimbursementRecord({
    required this.reimbursementId,
    required this.employeeId,
    required this.employeeName,
    required this.expenseDate,
    required this.category,
    required this.description,
    required this.amount,
    required this.statusId,
    required this.actionedByName,
  });

  factory ReimbursementRecord.fromJson(Map<String, dynamic> j) => ReimbursementRecord(
        reimbursementId: _asInt(j['ReimbursementID']),
        employeeId: _asInt(j['EmployeeID']),
        employeeName: _asString(j['EmployeeName']),
        expenseDate: _asString(j['ExpenseDate']),
        category: _asString(j['Category']),
        description: _asString(j['Description']),
        amount: _asDouble(j['Amount']),
        statusId: _asString(j['StatusID'], 'Pending'),
        actionedByName: j['ActionedByName'] as String?,
      );

  final int reimbursementId;
  final int employeeId;
  final String employeeName;
  final String expenseDate;
  final String category;
  final String description;
  final double amount;
  final String statusId;
  final String? actionedByName;
}

class SalaryRecord {
  SalaryRecord({
    required this.salaryId,
    required this.payMonth,
    required this.payYear,
    required this.amountDue,
    required this.amountPaid,
    required this.balance,
    required this.paymentDate,
    required this.paymentMode,
  });

  factory SalaryRecord.fromJson(Map<String, dynamic> j) => SalaryRecord(
        salaryId: _asInt(j['SalaryID']),
        payMonth: _asInt(j['PayMonth']),
        payYear: _asInt(j['PayYear']),
        amountDue: _asDouble(j['AmountDue']),
        amountPaid: _asDouble(j['AmountPaid']),
        balance: _asDouble(j['Balance']),
        paymentDate: j['PaymentDate'] as String?,
        paymentMode: j['PaymentMode'] as String?,
      );

  final int salaryId;
  final int payMonth;
  final int payYear;
  final double amountDue;
  final double amountPaid;
  final double balance;
  final String? paymentDate;
  final String? paymentMode;
}

class NotificationItem {
  NotificationItem({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.linkUrl,
    required this.notifyType,
    required this.isRead,
    required this.createdOn,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        notificationId: _asInt(j['NotificationID']),
        title: _asString(j['Title']),
        message: j['Message'] as String?,
        linkUrl: j['LinkUrl'] as String?,
        notifyType: j['NotifyType'] as String?,
        isRead: _asBool(j['IsRead']),
        createdOn: _asString(j['CreatedOn']),
      );

  final int notificationId;
  final String title;
  final String? message;
  final String? linkUrl;
  final String? notifyType;
  final bool isRead;
  final String createdOn;
}

class EmployeeSummary {
  EmployeeSummary({required this.id, required this.name});
  factory EmployeeSummary.fromJson(Map<String, dynamic> j) => EmployeeSummary(
        id: _asInt(j['ID']),
        name: _asString(j['FirstName'], _asString(j['Name'])),
      );
  final int id;
  final String name;
}

class VisitAssignment {
  VisitAssignment({
    required this.assignmentId,
    required this.title,
    required this.notes,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    required this.scheduledDate,
    required this.statusId,
    required this.assignedOn,
    required this.activeTripId,
    this.employeeId,
    this.employeeName,
  });

  factory VisitAssignment.fromJson(Map<String, dynamic> j) => VisitAssignment(
        assignmentId: _asInt(j['AssignmentID']),
        employeeId: j['EmployeeID'] != null ? _asInt(j['EmployeeID']) : null,
        employeeName: j['EmployeeName'] as String?,
        title: _asString(j['Title']),
        notes: j['Notes'] as String?,
        destinationLat: _asDouble(j['DestinationLat']),
        destinationLng: _asDouble(j['DestinationLng']),
        destinationAddress: j['DestinationAddress'] as String?,
        scheduledDate: j['ScheduledDate'] as String?,
        statusId: _asString(j['StatusID'], 'Pending'),
        assignedOn: _asString(j['AssignedOn']),
        activeTripId: j['ActiveTripID'] != null ? _asInt(j['ActiveTripID']) : null,
      );

  final int assignmentId;
  final int? employeeId;
  final String? employeeName;
  final String title;
  final String? notes;
  final double destinationLat;
  final double destinationLng;
  final String? destinationAddress;
  final String? scheduledDate;
  final String statusId;
  final String assignedOn;
  final int? activeTripId;
}

class TripDetail {
  TripDetail({
    required this.tripId,
    required this.assignmentId,
    required this.employeeId,
    required this.employeeName,
    required this.title,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    required this.startLat,
    required this.startLng,
    required this.statusId,
    required this.taskStatusId,
  });

  factory TripDetail.fromJson(Map<String, dynamic> j) => TripDetail(
        tripId: _asInt(j['TripID']),
        assignmentId: _asInt(j['AssignmentID']),
        employeeId: _asInt(j['EmployeeID']),
        employeeName: _asString(j['EmployeeName']),
        title: _asString(j['Title']),
        destinationLat: _asDouble(j['DestinationLat']),
        destinationLng: _asDouble(j['DestinationLng']),
        destinationAddress: j['DestinationAddress'] as String?,
        startLat: j['StartLat'] != null ? _asDouble(j['StartLat']) : null,
        startLng: j['StartLng'] != null ? _asDouble(j['StartLng']) : null,
        statusId: _asString(j['StatusID']),
        taskStatusId: _asString(j['TaskStatusID'], 'Pending'),
      );

  final int tripId;
  final int assignmentId;
  final int employeeId;
  final String employeeName;
  final String title;
  final double destinationLat;
  final double destinationLng;
  final String? destinationAddress;
  final double? startLat;
  final double? startLng;
  final String statusId;
  final String taskStatusId;
}

class TripPing {
  TripPing({required this.lat, required this.lng, required this.capturedOn});
  factory TripPing.fromJson(Map<String, dynamic> j) =>
      TripPing(lat: _asDouble(j['Lat']), lng: _asDouble(j['Lng']), capturedOn: _asString(j['CapturedOn']));
  final double lat;
  final double lng;
  final String capturedOn;
}

class ActiveTrip {
  ActiveTrip({
    required this.tripId,
    required this.employeeName,
    required this.title,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationAddress,
    required this.latestLat,
    required this.latestLng,
    required this.latestCapturedOn,
    required this.progressPct,
  });

  factory ActiveTrip.fromJson(Map<String, dynamic> j) => ActiveTrip(
        tripId: _asInt(j['TripID']),
        employeeName: _asString(j['EmployeeName']),
        title: _asString(j['Title']),
        destinationLat: _asDouble(j['DestinationLat']),
        destinationLng: _asDouble(j['DestinationLng']),
        destinationAddress: j['DestinationAddress'] as String?,
        latestLat: j['LatestLat'] != null ? _asDouble(j['LatestLat']) : null,
        latestLng: j['LatestLng'] != null ? _asDouble(j['LatestLng']) : null,
        latestCapturedOn: j['LatestCapturedOn'] as String?,
        progressPct: j['ProgressPct'] != null ? _asInt(j['ProgressPct']) : null,
      );

  final int tripId;
  final String employeeName;
  final String title;
  final double destinationLat;
  final double destinationLng;
  final String? destinationAddress;
  final double? latestLat;
  final double? latestLng;
  final String? latestCapturedOn;
  final int? progressPct;
}

class OvertimeLogRecord {
  OvertimeLogRecord({
    required this.otLogId,
    required this.employeeName,
    required this.otDate,
    required this.hours,
    required this.description,
    required this.statusId,
    required this.actionRemarks,
  });

  factory OvertimeLogRecord.fromJson(Map<String, dynamic> j) => OvertimeLogRecord(
        otLogId: _asInt(j['OTLogID']),
        employeeName: j['EmployeeName'] as String? ?? '',
        otDate: _asString(j['OTDate']),
        hours: _asDouble(j['Hours']),
        description: j['Description'] as String?,
        statusId: _asString(j['StatusID'], 'Pending'),
        actionRemarks: j['ActionRemarks'] as String?,
      );

  final int otLogId;
  final String employeeName;
  final String otDate;
  final double hours;
  final String? description;
  final String statusId;
  final String? actionRemarks;
}

class AdminDashboardSummary {
  AdminDashboardSummary({
    required this.totalEmployees,
    required this.presentToday,
    required this.punchedOutToday,
    required this.pendingReimbursementCount,
    required this.pendingLeaveCount,
  });

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> j) => AdminDashboardSummary(
        totalEmployees: _asInt(j['totalEmployees']),
        presentToday: _asInt(j['presentToday']),
        punchedOutToday: _asInt(j['punchedOutToday']),
        pendingReimbursementCount: _asInt(j['pendingReimbursementCount']),
        pendingLeaveCount: _asInt(j['pendingLeaveCount']),
      );

  final int totalEmployees;
  final int presentToday;
  final int punchedOutToday;
  final int pendingReimbursementCount;
  final int pendingLeaveCount;
}
