import '../core/api_client.dart';
import '../models/home_models.dart';

/// Data behind the redesigned Home screens (employee: month calendar + leave balance; admin: today board,
/// approvals queue, week bars, tasks, payroll). Server side: HomeDashboardService, shared with the web.
class HomeService {
  final _client = ApiClient.instance;

  Future<MonthCalendar> getHomeCalendar({int? month, int? year}) async {
    final res = await _client.get('/EmployeeApp/GetHomeCalendar', query: {
      'month': ?month,
      'year': ?year,
    });
    final data = res.data as Map<String, dynamic>;
    final days = ((data['days'] as List?) ?? const []).cast<Map<String, dynamic>>().map(CalendarDay.fromJson).toList();
    final summary = data['summary'] as Map<String, dynamic>?;
    return MonthCalendar(days: days, summary: summary == null ? null : MonthSummary.fromJson(summary));
  }

  Future<List<LeaveBalanceItem>> getLeaveBalance() async {
    final res = await _client.get('/EmployeeApp/GetLeaveBalance');
    return (res.data as List).cast<Map<String, dynamic>>().map(LeaveBalanceItem.fromJson).toList();
  }

  // ---- Admin ----

  Future<AdminHome> getAdminHome() async {
    final res = await _client.get('/EmployeeApp/GetAdminHome');
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return AdminHome.fromJson(res.data as Map<String, dynamic>);
  }

  /// Returns how many people were reminded (and how many were skipped because they were reminded in the last hour).
  Future<({int sent, int skipped})> remindNotCheckedIn() async {
    final res = await _client.post('/EmployeeApp/RemindNotCheckedIn');
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    final data = res.data as Map<String, dynamic>;
    return (sent: (data['sent'] as num?)?.toInt() ?? 0, skipped: (data['skipped'] as num?)?.toInt() ?? 0);
  }
}

/// Company Updates: the merged feed (notices, holidays, events, birthdays, work anniversaries) and, for admins,
/// posting / editing / removing. Server side: CompanyUpdatesService, shared with the web.
class CompanyUpdatesApi {
  final _client = ApiClient.instance;

  Future<List<CompanyUpdate>> getFeed({int upcomingDays = 30, int pastDays = 0}) async {
    final res = await _client.get('/EmployeeApp/GetCompanyFeed', query: {'upcomingDays': upcomingDays, 'pastDays': pastDays});
    return (res.data as List).cast<Map<String, dynamic>>().map(CompanyUpdate.fromJson).toList();
  }

  Future<void> markRead({int? updateId}) async {
    await _client.post('/EmployeeApp/MarkCompanyUpdatesRead', data: {'updateId': ?updateId});
  }

  Future<void> save({
    int? updateId,
    required String type,
    required String title,
    String? description,
    required DateTime startDate,
    DateTime? endDate,
    String? startTime,
    String? location,
    bool pinned = false,
  }) async {
    String iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await _client.post('/EmployeeApp/SaveCompanyUpdate', data: {
      'updateId': updateId ?? 0,
      'updateType': type,
      'title': title,
      'description': description ?? '',
      'startDate': iso(startDate),
      'endDate': endDate == null ? '' : iso(endDate),
      'startTime': startTime ?? '',
      'location': location ?? '',
      'isPinned': pinned,
    });
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not save the update.'));
    }
  }

  Future<void> delete(int updateId) async {
    final res = await _client.post('/EmployeeApp/DeleteCompanyUpdate', data: {'updateId': updateId});
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not remove the update.'));
    }
  }
}
