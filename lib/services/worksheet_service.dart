import '../core/api_client.dart';
import '../models/worksheet_models.dart';

/// Worksheet = the same Timesheet table the web "My Worksheet" page uses (see EmployeeAppController's
/// WORKSHEET section), so what an employee logs here shows up on the web and in the admin report at once.
class WorksheetService {
  final _client = ApiClient.instance;

  List<Map<String, dynamic>> _rows(dynamic data) => (data as List).cast<Map<String, dynamic>>();

  Future<List<WorksheetProject>> getMyProjects() async {
    final res = await _client.get('/EmployeeApp/GetMyWorksheetProjects');
    return _rows(res.data).map(WorksheetProject.fromJson).toList();
  }

  Future<List<WorksheetTask>> getMyTasks(int projectId) async {
    final res = await _client.get('/EmployeeApp/GetMyWorksheetTasks', query: {'projectId': projectId});
    return _rows(res.data).map(WorksheetTask.fromJson).toList();
  }

  /// Rows for [from]..[to] inclusive (one day: same date twice), newest first.
  Future<List<WorksheetEntry>> getMyWorksheet(DateTime from, DateTime to) async {
    final res = await _client.get('/EmployeeApp/GetMyWorksheet', query: {'from': worksheetIso(from), 'to': worksheetIso(to)});
    return _rows(res.data).map(WorksheetEntry.fromJson).toList();
  }

  Future<WorksheetSummary> getSummary(DateTime date) async {
    final res = await _client.get('/EmployeeApp/GetMyWorksheetSummary', query: {'date': worksheetIso(date)});
    return WorksheetSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// [id] 0 adds a new entry, otherwise edits that (Pending) one.
  Future<void> saveEntry({
    int id = 0,
    required int projectId,
    int? taskId,
    required String taskName,
    required DateTime date,
    required double hours,
    String? description,
  }) async {
    final res = await _client.post('/EmployeeApp/SaveMyWorksheetEntry', data: {
      'id': id,
      'projectId': projectId,
      'taskId': ?taskId,
      'taskName': taskName,
      'entryDate': worksheetIso(date),
      'hours': hours,
      'notes': description ?? '',
    });
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not save this entry.'));
    }
  }

  Future<void> deleteEntry(int id) async {
    final res = await _client.post('/EmployeeApp/DeleteMyWorksheetEntry', data: {'id': id});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not delete this entry.'));
    }
  }

  // ---- Admin ----

  Future<({List<WorksheetFilterOption> employees, List<WorksheetFilterOption> projects})> getFilterOptions() async {
    final res = await _client.get('/EmployeeApp/GetWorksheetFilterOptions');
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    final data = res.data as Map<String, dynamic>;
    List<WorksheetFilterOption> opts(String key, String nameKey) => (data[key] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((e) => WorksheetFilterOption(id: int.tryParse('${e['ID']}') ?? 0, name: '${e[nameKey] ?? ''}'))
        .toList();
    return (employees: opts('employees', 'Name'), projects: opts('projects', 'ProjectName'));
  }

  /// [status]: null = Pending + Approved, 'All', 'Approved', 'Pending' or 'Rejected'.
  Future<WorksheetReport> getReport({
    required DateTime from,
    required DateTime to,
    int? employeeId,
    int? projectId,
    String? status,
  }) async {
    final res = await _client.get('/EmployeeApp/GetWorksheetReport', query: {
      'from': worksheetIso(from),
      'to': worksheetIso(to),
      'employeeId': ?employeeId,
      'projectId': ?projectId,
      'status': ?status,
    });
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return WorksheetReport.fromJson(res.data as Map<String, dynamic>);
  }
}
