/// Models for the Worksheet (project / task name / description / hours per day) — see WorksheetService.
/// Field names match what /EmployeeApp/GetMyWorksheet*, GetWorksheetReport return (SQL column casing).
library;

int _int(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

double _double(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String _str(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;

/// Date-only value ("2026-11-23") in ISO form — what the API sends/accepts for a worksheet day.
String worksheetIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A project the employee is tagged to (the only ones they can log hours against).
class WorksheetProject {
  WorksheetProject({required this.id, required this.name, required this.code});

  factory WorksheetProject.fromJson(Map<String, dynamic> j) =>
      WorksheetProject(id: _int(j['ID']), name: _str(j['ProjectName']), code: _str(j['ProjectCode']));

  final int id;
  final String name;
  final String code;
}

/// An open task assigned to the employee — offered as a suggestion for the task name.
class WorksheetTask {
  WorksheetTask({required this.id, required this.title});

  factory WorksheetTask.fromJson(Map<String, dynamic> j) => WorksheetTask(id: _int(j['ID']), title: _str(j['Title']));

  final int id;
  final String title;
}

class WorksheetEntry {
  WorksheetEntry({
    required this.id,
    required this.entryDate,
    required this.projectId,
    required this.projectName,
    required this.projectCode,
    required this.taskId,
    required this.taskName,
    required this.description,
    required this.hours,
    required this.status,
    required this.rejectReason,
  });

  factory WorksheetEntry.fromJson(Map<String, dynamic> j) => WorksheetEntry(
        id: _int(j['ID']),
        entryDate: _str(j['EntryDate']),
        projectId: _int(j['ProjectID']),
        projectName: _str(j['ProjectName']),
        projectCode: _str(j['ProjectCode']),
        taskId: j['TaskID'] == null ? null : _int(j['TaskID']),
        taskName: _str(j['TaskName']),
        description: _str(j['Description']),
        hours: _double(j['Hours']),
        status: _str(j['StatusID'], 'Pending'),
        rejectReason: _str(j['RejectReason']),
      );

  final int id;
  final String entryDate; // yyyy-MM-dd
  final int projectId;
  final String projectName;
  final String projectCode;
  final int? taskId;
  final String taskName;
  final String description;
  final double hours;
  final String status;
  final String rejectReason;

  /// Only a Pending entry can still be edited or deleted (the server enforces it too).
  bool get canEdit => status == 'Pending';
}

class WorksheetWeekDay {
  WorksheetWeekDay({required this.date, required this.dayName, required this.dayNo, required this.hours});

  factory WorksheetWeekDay.fromJson(Map<String, dynamic> j) =>
      WorksheetWeekDay(date: _str(j['D']), dayName: _str(j['DayName']), dayNo: _int(j['DayNo']), hours: _double(j['Hours']));

  final String date; // yyyy-MM-dd
  final String dayName;
  final int dayNo;
  final double hours;
}

class WorksheetProjectHours {
  WorksheetProjectHours({required this.name, required this.hours});

  factory WorksheetProjectHours.fromJson(Map<String, dynamic> j) =>
      WorksheetProjectHours(name: _str(j['ProjectName']), hours: _double(j['Hours']));

  final String name;
  final double hours;
}

/// Header numbers + Mon-Sun strip + this-month-by-project split for the selected day.
class WorksheetSummary {
  WorksheetSummary({
    required this.dayHours,
    required this.weekHours,
    required this.monthHours,
    required this.monthDaysLogged,
    required this.monthPending,
    required this.monthApproved,
    required this.monthRejected,
    required this.standardHours,
    required this.week,
    required this.projects,
  });

  factory WorksheetSummary.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as List? ?? const []).cast<Map<String, dynamic>>();
    final row = s.isNotEmpty ? s.first : const <String, dynamic>{};
    return WorksheetSummary(
      dayHours: _double(row['DayHours']),
      weekHours: _double(row['WeekHours']),
      monthHours: _double(row['MonthHours']),
      monthDaysLogged: _int(row['MonthDaysLogged']),
      monthPending: _double(row['MonthPending']),
      monthApproved: _double(row['MonthApproved']),
      monthRejected: _double(row['MonthRejected']),
      standardHours: _double(row['StandardHours'], 8) <= 0 ? 8 : _double(row['StandardHours'], 8),
      week: (j['week'] as List? ?? const []).cast<Map<String, dynamic>>().map(WorksheetWeekDay.fromJson).toList(),
      projects: (j['projects'] as List? ?? const []).cast<Map<String, dynamic>>().map(WorksheetProjectHours.fromJson).toList(),
    );
  }

  final double dayHours;
  final double weekHours;
  final double monthHours;
  final int monthDaysLogged;
  final double monthPending;
  final double monthApproved;
  final double monthRejected;
  final double standardHours;
  final List<WorksheetWeekDay> week;
  final List<WorksheetProjectHours> projects;
}

// ============================== Admin report ==============================

class WorksheetFilterOption {
  WorksheetFilterOption({required this.id, required this.name});
  final int id;
  final String name;
}

class WorksheetKpi {
  WorksheetKpi({
    required this.totalHours,
    required this.approvedHours,
    required this.pendingHours,
    required this.rejectedHours,
    required this.entries,
    required this.employeesLogged,
    required this.projectsWorked,
    required this.expectedHours,
    required this.missingDays,
    required this.employeesInScope,
  });

  factory WorksheetKpi.fromJson(Map<String, dynamic> j) => WorksheetKpi(
        totalHours: _double(j['TotalHours']),
        approvedHours: _double(j['ApprovedHours']),
        pendingHours: _double(j['PendingHours']),
        rejectedHours: _double(j['RejectedHours']),
        entries: _int(j['Entries']),
        employeesLogged: _int(j['EmployeesLogged']),
        projectsWorked: _int(j['ProjectsWorked']),
        expectedHours: _double(j['ExpectedHours']),
        missingDays: _int(j['MissingDays']),
        employeesInScope: _int(j['EmployeesInScope']),
      );

  final double totalHours;
  final double approvedHours;
  final double pendingHours;
  final double rejectedHours;
  final int entries;
  final int employeesLogged;
  final int projectsWorked;
  final double expectedHours;
  final int missingDays;
  final int employeesInScope;

  /// Logged / expected, in percent; null when there is nothing to compare against.
  double? get utilisation => expectedHours > 0 ? totalHours / expectedHours * 100 : null;
}

class WorksheetProjectRow {
  WorksheetProjectRow({
    required this.projectId,
    required this.name,
    required this.code,
    required this.totalHours,
    required this.approvedHours,
    required this.pendingHours,
    required this.employees,
    required this.days,
    required this.entries,
  });

  factory WorksheetProjectRow.fromJson(Map<String, dynamic> j) => WorksheetProjectRow(
        projectId: _int(j['ProjectID']),
        name: _str(j['ProjectName']),
        code: _str(j['ProjectCode']),
        totalHours: _double(j['TotalHours']),
        approvedHours: _double(j['ApprovedHours']),
        pendingHours: _double(j['PendingHours']),
        employees: _int(j['Employees']),
        days: _int(j['Days']),
        entries: _int(j['Entries']),
      );

  final int projectId;
  final String name;
  final String code;
  final double totalHours;
  final double approvedHours;
  final double pendingHours;
  final int employees;
  final int days;
  final int entries;
}

class WorksheetEmployeeRow {
  WorksheetEmployeeRow({
    required this.employeeId,
    required this.name,
    required this.department,
    required this.totalHours,
    required this.approvedHours,
    required this.pendingHours,
    required this.daysLogged,
    required this.projects,
    required this.avgPerDay,
    required this.expectedHours,
    required this.missingDays,
  });

  factory WorksheetEmployeeRow.fromJson(Map<String, dynamic> j) => WorksheetEmployeeRow(
        employeeId: _int(j['EmployeeID']),
        name: _str(j['Employee']),
        department: _str(j['Department']),
        totalHours: _double(j['TotalHours']),
        approvedHours: _double(j['ApprovedHours']),
        pendingHours: _double(j['PendingHours']),
        daysLogged: _int(j['DaysLogged']),
        projects: _int(j['Projects']),
        avgPerDay: _double(j['AvgPerDay']),
        expectedHours: j['ExpectedHours'] == null ? null : _double(j['ExpectedHours']),
        missingDays: j['MissingDays'] == null ? null : _int(j['MissingDays']),
      );

  final int employeeId;
  final String name;
  final String department;
  final double totalHours;
  final double approvedHours;
  final double pendingHours;
  final int daysLogged;
  final int projects;
  final double avgPerDay;
  final double? expectedHours; // null when a project filter is on
  final int? missingDays;

  double? get utilisation => (expectedHours ?? 0) > 0 ? totalHours / expectedHours! * 100 : null;
}

class WorksheetDayRow {
  WorksheetDayRow({required this.date, required this.dayName, required this.totalHours, required this.employees, required this.entries});

  factory WorksheetDayRow.fromJson(Map<String, dynamic> j) => WorksheetDayRow(
        date: _str(j['EntryDate']),
        dayName: _str(j['DayName']),
        totalHours: _double(j['TotalHours']),
        employees: _int(j['Employees']),
        entries: _int(j['Entries']),
      );

  final String date;
  final String dayName;
  final double totalHours;
  final int employees;
  final int entries;
}

class WorksheetDetailRow {
  WorksheetDetailRow({
    required this.id,
    required this.date,
    required this.employee,
    required this.project,
    required this.task,
    required this.description,
    required this.hours,
    required this.status,
    required this.rejectReason,
  });

  factory WorksheetDetailRow.fromJson(Map<String, dynamic> j) => WorksheetDetailRow(
        id: _int(j['ID']),
        date: _str(j['EntryDate']),
        employee: _str(j['Employee']),
        project: _str(j['ProjectName']),
        task: _str(j['TaskName']),
        description: _str(j['Description']),
        hours: _double(j['Hours']),
        status: _str(j['Status'], 'Pending'),
        rejectReason: _str(j['RejectReason']),
      );

  final int id;
  final String date;
  final String employee;
  final String project;
  final String task;
  final String description;
  final double hours;
  final String status;
  final String rejectReason;
}

class WorksheetReport {
  WorksheetReport({required this.kpi, required this.byProject, required this.byEmployee, required this.byDay, required this.detail});

  factory WorksheetReport.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> rows(String key) => (j[key] as List? ?? const []).cast<Map<String, dynamic>>();
    final k = rows('kpi');
    return WorksheetReport(
      kpi: WorksheetKpi.fromJson(k.isNotEmpty ? k.first : const <String, dynamic>{}),
      byProject: rows('byProject').map(WorksheetProjectRow.fromJson).toList(),
      byEmployee: rows('byEmployee').map(WorksheetEmployeeRow.fromJson).toList(),
      byDay: rows('byDay').map(WorksheetDayRow.fromJson).toList(),
      detail: rows('detail').map(WorksheetDetailRow.fromJson).toList(),
    );
  }

  final WorksheetKpi kpi;
  final List<WorksheetProjectRow> byProject;
  final List<WorksheetEmployeeRow> byEmployee;
  final List<WorksheetDayRow> byDay;
  final List<WorksheetDetailRow> detail;
}
