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
