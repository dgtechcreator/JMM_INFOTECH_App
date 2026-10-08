/// Models for the redesigned Home screens and Company Updates (see HomeService / CompanyUpdatesService).
/// Field names match what /EmployeeApp/GetHomeCalendar, GetLeaveBalance, GetCompanyFeed and GetAdminHome
/// return (DataTable columns keep their SQL casing).
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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

bool _bool(dynamic v) {
  if (v is bool) return v;
  if (v == null) return false;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1';
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  final d = DateTime.tryParse(v.toString());
  return d?.toLocal();
}

// ============================== Company updates ==============================

/// One row of the merged feed: a notice, holiday or event posted by an admin, or an automatic birthday /
/// work anniversary.
class CompanyUpdate {
  CompanyUpdate({
    required this.itemKey,
    required this.type,
    required this.sourceId,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.endDate,
    required this.startTime,
    required this.location,
    required this.daysAway,
    required this.bucket,
    required this.isPinned,
    required this.isNew,
    required this.postedBy,
    required this.postedOn,
    required this.department,
  });

  factory CompanyUpdate.fromJson(Map<String, dynamic> j) => CompanyUpdate(
        itemKey: _str(j['ItemKey']),
        type: _str(j['ItemType'], 'Notice'),
        sourceId: _int(j['SourceID']),
        title: _str(j['Title']),
        description: j['Description'] as String?,
        eventDate: _date(j['EventDate']),
        endDate: _date(j['EndDate']),
        startTime: j['StartTime'] as String?,
        location: j['Location'] as String?,
        daysAway: _int(j['DaysAway']),
        bucket: _str(j['Bucket'], 'Upcoming'),
        isPinned: _bool(j['IsPinned']),
        isNew: _bool(j['IsNew']),
        postedBy: j['PostedBy'] as String?,
        postedOn: _date(j['PostedOn']),
        department: j['Department'] as String?,
      );

  final String itemKey;

  /// Notice | Holiday | Event | Birthday | Anniversary
  final String type;

  /// UpdateID for notice/holiday/event (what edit/delete use), EmployeeID for birthday/anniversary.
  final int sourceId;
  final String title;
  final String? description;
  final DateTime? eventDate;
  final DateTime? endDate;
  final String? startTime;
  final String? location;
  final int daysAway;

  /// Notice (live now) | Today | Upcoming | Past
  final String bucket;
  final bool isPinned;
  final bool isNew;
  final String? postedBy;
  final DateTime? postedOn;
  final String? department;

  /// Only notices, holidays and events are posted (and therefore editable); birthdays/anniversaries are automatic.
  bool get isPosted => type == 'Notice' || type == 'Holiday' || type == 'Event';

  IconData get icon {
    switch (type) {
      case 'Holiday':
        return Icons.beach_access_outlined;
      case 'Event':
        return Icons.event_available_outlined;
      case 'Birthday':
        return Icons.cake_outlined;
      case 'Anniversary':
        return Icons.workspace_premium_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }

  Color get color {
    switch (type) {
      case 'Holiday':
        return const Color(0xFF9333EA);
      case 'Event':
        return AppColors.info;
      case 'Birthday':
        return const Color(0xFFDB2777);
      case 'Anniversary':
        return const Color(0xFF0D9488);
      default:
        return AppColors.warning;
    }
  }

  String get typeLabel => type == 'Anniversary' ? 'Work anniversary' : type;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  String get dateRangeText {
    final s = eventDate, e = endDate;
    if (s == null) return '';
    if (e != null && (e.year != s.year || e.month != s.month || e.day != s.day)) return '${_day(s)} - ${_day(e)}';
    return _day(s);
  }

  /// "Today" / "Tomorrow" / "in 5 days" / "2 days ago"
  String get whenText {
    if (bucket == 'Today') return 'Today';
    if (daysAway == 0) return 'Today';
    if (daysAway == 1) return 'Tomorrow';
    if (daysAway == -1) return 'Yesterday';
    return daysAway > 0 ? 'in $daysAway days' : '${-daysAway} days ago';
  }

  static String _ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }

  /// The grey line under the title. [withWhen] adds the relative time ("in 3 days"), which the full-size card
  /// shows as a pill instead.
  String subtitle({bool withWhen = true}) {
    final parts = <String>[];
    switch (type) {
      case 'Notice':
        parts.add('${(postedBy ?? '').isEmpty ? 'Company' : postedBy} · ${_ago(postedOn)}');
        break;
      case 'Holiday':
        parts.add('Office closed');
        parts.add(bucket == 'Today' ? 'Today' : dateRangeText);
        if (withWhen && bucket == 'Upcoming') parts.add(whenText);
        break;
      case 'Event':
        parts.add('$dateRangeText${(startTime ?? '').isEmpty ? '' : ' at $startTime'}');
        if ((location ?? '').isNotEmpty) parts.add(location!);
        if (withWhen) parts.add(whenText);
        break;
      case 'Birthday':
        parts.add((department ?? '').isEmpty ? 'Birthday' : department!);
        if (withWhen) parts.add(whenText);
        break;
      case 'Anniversary':
        parts.add((description ?? '').isEmpty ? 'Work anniversary' : description!);
        if (withWhen) parts.add(whenText);
        break;
    }
    return parts.join(' · ');
  }

  /// A short list for a Home card: what is happening today first, then live notices (unread first), then the
  /// nearest upcoming items.
  static List<CompanyUpdate> pick(List<CompanyUpdate> all, int max) {
    final today = all.where((u) => u.bucket == 'Today').toList();
    final notices = all.where((u) => u.bucket == 'Notice').toList()
      ..sort((a, b) => (b.isNew ? 1 : 0) - (a.isNew ? 1 : 0) != 0 ? (b.isNew ? 1 : 0) - (a.isNew ? 1 : 0) : (b.isPinned ? 1 : 0) - (a.isPinned ? 1 : 0));
    final upcoming = all.where((u) => u.bucket == 'Upcoming').toList();
    return [...today, ...notices, ...upcoming].take(max).toList();
  }
}

// ============================== Employee home ==============================

/// One day of the Home screen's month calendar.
class CalendarDay {
  CalendarDay({required this.date, required this.dayNo, required this.weekday, required this.status, required this.isToday, required this.isWfh, this.note});

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
        date: _date(j['DayDate']),
        dayNo: _int(j['DayNo']),
        weekday: _int(j['DayOfWeekNo']),
        status: _str(j['Status']),
        isToday: _bool(j['IsToday']),
        isWfh: _bool(j['IsWfh']),
        note: j['Note'] as String?,
      );

  final DateTime? date;
  final int dayNo;

  /// 0 = Monday ... 6 = Sunday
  final int weekday;

  /// Present | HalfDay | Absent | Leave | Holiday | WeekOff | NA | Future | Today
  final String status;
  final bool isToday;
  final bool isWfh;
  final String? note;
}

class MonthSummary {
  MonthSummary({
    required this.presentDays,
    required this.halfDays,
    required this.absentDays,
    required this.leaveDays,
    required this.holidayDays,
    required this.wfhDays,
    required this.standardHours,
    required this.officeStart,
    required this.officeEnd,
  });

  factory MonthSummary.fromJson(Map<String, dynamic> j) => MonthSummary(
        presentDays: _int(j['PresentDays']),
        halfDays: _int(j['HalfDays']),
        absentDays: _int(j['AbsentDays']),
        leaveDays: _int(j['LeaveDays']),
        holidayDays: _int(j['HolidayDays']),
        wfhDays: _int(j['WfhDays']),
        standardHours: _double(j['StandardHours'], 8),
        officeStart: _str(j['OfficeStartText']),
        officeEnd: _str(j['OfficeEndText']),
      );

  final int presentDays;
  final int halfDays;
  final int absentDays;
  final int leaveDays;
  final int holidayDays;
  final int wfhDays;
  final double standardHours;
  final String officeStart;
  final String officeEnd;
}

class MonthCalendar {
  MonthCalendar({required this.days, required this.summary});
  final List<CalendarDay> days;
  final MonthSummary? summary;
}

class LeaveBalanceItem {
  LeaveBalanceItem({required this.title, required this.quota, required this.used, required this.pending, required this.remaining});

  factory LeaveBalanceItem.fromJson(Map<String, dynamic> j) => LeaveBalanceItem(
        title: _str(j['Title']),
        quota: j['AnnualQuota'] == null ? null : _double(j['AnnualQuota']),
        used: _double(j['UsedDays']),
        pending: _double(j['PendingDays']),
        remaining: j['RemainingDays'] == null ? null : _double(j['RemainingDays']),
      );

  final String title;
  final double? quota;
  final double used;
  final double pending;
  final double? remaining;

  static String fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ============================== Admin home ==============================

class TeamMemberToday {
  TeamMemberToday({required this.employeeId, required this.name, required this.status, required this.punchInText, required this.isLateIn, required this.note, required this.expectedBy, required this.workMode});

  factory TeamMemberToday.fromJson(Map<String, dynamic> j) => TeamMemberToday(
        employeeId: _int(j['EmployeeID']),
        name: _str(j['FullName']).trim(),
        status: _str(j['Status']),
        punchInText: j['PunchInText'] as String?,
        isLateIn: _bool(j['IsLateIn']),
        note: j['Note'] as String?,
        expectedBy: _str(j['ExpectedBy']),
        workMode: j['WorkMode'] as String?,
      );

  final int employeeId;
  final String name;

  /// Present | WFH | Leave | NotYet | Late | Absent | Off
  final String status;
  final String? punchInText;
  final bool isLateIn;
  final String? note;
  final String expectedBy;
  final String? workMode;

  String get initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get statusLabel {
    switch (status) {
      case 'NotYet':
        return 'Not yet';
      case 'Off':
        return 'Day off';
      default:
        return status;
    }
  }

  Color get color {
    switch (status) {
      case 'Present':
        return AppColors.success;
      case 'WFH':
        return AppColors.info;
      case 'Leave':
        return AppColors.onLeave;
      case 'Late':
        return AppColors.warning;
      case 'Absent':
        return AppColors.danger;
      default:
        return AppColors.holiday;
    }
  }

  String get subtitle {
    switch (status) {
      case 'Present':
        return 'Checked in ${punchInText ?? ''} · Office${isLateIn ? ' · late' : ''}';
      case 'WFH':
        return punchInText != null ? 'Working from home since $punchInText' : (note ?? 'Work from home');
      case 'Leave':
        return 'On leave${(note ?? '').isEmpty ? '' : ' · $note'}';
      case 'Absent':
        return 'No check-in today';
      case 'Off':
        return (note ?? '').isEmpty ? 'Day off' : note!;
      default:
        return 'Expected by $expectedBy';
    }
  }
}

class TodaySummary {
  TodaySummary({
    required this.todayType,
    required this.holidayTitle,
    required this.officeStart,
    required this.officeEnd,
    required this.totalExpected,
    required this.punchedIn,
    required this.present,
    required this.wfh,
    required this.leave,
    required this.notCheckedIn,
    required this.late,
  });

  factory TodaySummary.fromJson(Map<String, dynamic> j) => TodaySummary(
        todayType: _str(j['TodayType'], 'Working'),
        holidayTitle: j['HolidayTitle'] as String?,
        officeStart: _str(j['OfficeStartText']),
        officeEnd: _str(j['OfficeEndText']),
        totalExpected: _int(j['TotalExpected']),
        punchedIn: _int(j['PunchedInCount']),
        present: _int(j['PresentCount']),
        wfh: _int(j['WfhCount']),
        leave: _int(j['LeaveCount']),
        notCheckedIn: _int(j['NotCheckedInCount']),
        late: _int(j['LateCount']),
      );

  final String todayType;
  final String? holidayTitle;
  final String officeStart;
  final String officeEnd;
  final int totalExpected;
  final int punchedIn;
  final int present;
  final int wfh;
  final int leave;
  final int notCheckedIn;
  final int late;

  bool get isWorkingDay => todayType == 'Working';
}

class WeekDayCount {
  WeekDayCount({required this.label, required this.present, required this.total, required this.isToday, required this.isOff});

  factory WeekDayCount.fromJson(Map<String, dynamic> j) => WeekDayCount(
        label: _str(j['DayLabel']),
        present: _int(j['PresentCount']),
        total: _int(j['TotalEmployees']),
        isToday: _int(j['IsToday']) == 1,
        isOff: _int(j['IsOff']) == 1,
      );

  final String label;
  final int present;
  final int total;
  final bool isToday;
  final bool isOff;
}

class PendingApproval {
  PendingApproval({required this.kind, required this.refId, required this.title, required this.subtitle, required this.amount});

  factory PendingApproval.fromJson(Map<String, dynamic> j) => PendingApproval(
        kind: _str(j['Kind']),
        refId: _int(j['RefID']),
        title: _str(j['Title']),
        subtitle: _str(j['Subtitle']),
        amount: j['Amount'] == null ? null : _double(j['Amount']),
      );

  /// Leave | WFH | Reimbursement | Overtime
  final String kind;
  final int refId;
  final String title;
  final String subtitle;
  final double? amount;

  IconData get icon {
    switch (kind) {
      case 'Leave':
        return Icons.event_note_outlined;
      case 'WFH':
        return Icons.home_work_outlined;
      case 'Reimbursement':
        return Icons.receipt_long_outlined;
      default:
        return Icons.timer_outlined;
    }
  }

  Color get color {
    switch (kind) {
      case 'Leave':
        return AppColors.primary;
      case 'WFH':
        return AppColors.info;
      case 'Reimbursement':
        return AppColors.success;
      default:
        return AppColors.holiday;
    }
  }
}

class DueTask {
  DueTask({required this.title, required this.status, required this.daysToDue, required this.dueDate, required this.assignedTo});

  factory DueTask.fromJson(Map<String, dynamic> j) => DueTask(
        title: _str(j['Title']),
        status: _str(j['StatusText']),
        daysToDue: j['DaysToDue'] == null ? null : _int(j['DaysToDue']),
        dueDate: _date(j['DueDate']),
        assignedTo: _str(j['AssignedTo']),
      );

  final String title;
  final String status;
  final int? daysToDue;
  final DateTime? dueDate;
  final String assignedTo;
}

class PayrollSnapshot {
  PayrollSnapshot({required this.monthName, required this.pending, required this.paid, required this.active, required this.runStatus, required this.monthEnd, required this.daysLeft});

  factory PayrollSnapshot.fromJson(Map<String, dynamic> j) => PayrollSnapshot(
        monthName: _str(j['MonthName']),
        pending: _int(j['PendingCount']),
        paid: _int(j['PaidCount']),
        active: _int(j['ActiveEmployees']),
        runStatus: j['RunStatus'] as String?,
        monthEnd: _str(j['MonthEndText']),
        daysLeft: _int(j['DaysLeft']),
      );

  final String monthName;
  final int pending;
  final int paid;
  final int active;
  final String? runStatus;
  final String monthEnd;
  final int daysLeft;
}

class AdminHome {
  AdminHome({
    required this.board,
    required this.summary,
    required this.week,
    required this.approvals,
    required this.leavePending,
    required this.wfhPending,
    required this.reimbursementPending,
    required this.overtimePending,
    required this.totalPending,
    required this.tasksDue,
    required this.dueTasks,
    required this.payroll,
  });

  factory AdminHome.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? const []).cast<Map<String, dynamic>>().map(f).toList();
    final counts = (j['approvalCounts'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final summary = j['boardSummary'] as Map<String, dynamic>?;
    final payroll = j['payroll'] as Map<String, dynamic>?;
    return AdminHome(
      board: list('board', TeamMemberToday.fromJson),
      summary: summary == null ? null : TodaySummary.fromJson(summary),
      week: list('week', WeekDayCount.fromJson),
      approvals: list('approvals', PendingApproval.fromJson),
      leavePending: _int(counts['LeavePending']),
      wfhPending: _int(counts['WfhPending']),
      reimbursementPending: _int(counts['ReimbursementPending']),
      overtimePending: _int(counts['OvertimePending']),
      totalPending: _int(counts['TotalPending']),
      tasksDue: _int(counts['TasksDue']),
      dueTasks: list('dueTasks', DueTask.fromJson),
      payroll: payroll == null ? null : PayrollSnapshot.fromJson(payroll),
    );
  }

  final List<TeamMemberToday> board;
  final TodaySummary? summary;
  final List<WeekDayCount> week;
  final List<PendingApproval> approvals;
  final int leavePending;
  final int wfhPending;
  final int reimbursementPending;
  final int overtimePending;
  final int totalPending;
  final int tasksDue;
  final List<DueTask> dueTasks;
  final PayrollSnapshot? payroll;

  /// Employees who could still punch in today (not yet / late) - the "Remind all" audience.
  int get canStillPunch => board.where((m) => m.status == 'NotYet' || m.status == 'Late').length;
}
