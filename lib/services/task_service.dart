import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/models.dart';

class TaskService {
  final _client = ApiClient.instance;

  Future<List<TaskItem>> getMyTasks() async {
    final res = await _client.get('/EmployeeApp/GetMyTasks');
    return (res.data as List).cast<Map<String, dynamic>>().map(TaskItem.fromJson).toList();
  }

  Future<List<TaskStatusOption>> getTaskStatusOptions() async {
    final res = await _client.get('/EmployeeApp/GetTaskStatusOptions');
    return (res.data as List).cast<Map<String, dynamic>>().map(TaskStatusOption.fromJson).toList();
  }

  Future<void> updateMyTaskStatus(int id, int status) async {
    final res = await _client.post('/EmployeeApp/UpdateMyTaskStatus', data: {'id': id, 'status': status});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not update task status.'));
    }
  }

  // ---- Admin ----

  Future<List<Map<String, dynamic>>> getTaskList() async {
    final res = await _client.get('/EmployeeApp/GetTaskList');
    if (res.statusCode == 403) {
      throw ApiException(extractMessage(res.data, 'No admin access.'), statusCode: 403);
    }
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<EmployeeSummary>> getEmployeesDropdown() async {
    final res = await _client.get('/EmployeeApp/GetEmployeesDropdown');
    return (res.data as List).cast<Map<String, dynamic>>().map(EmployeeSummary.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> getTaskPriorityDropdown() async {
    final res = await _client.get('/EmployeeApp/GetTaskPriorityDropdown');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> assignTask({
    required String title,
    int? projectId,
    required int taskPriority,
    required int assignToEmployeeId,
    String? dueDate,
    required int status,
  }) async {
    final form = FormData.fromMap({
      'Title': title,
      'ProjectID': projectId ?? 0,
      'TaskPriority': taskPriority,
      'AssignTo': assignToEmployeeId.toString(),
      'DueDate': ?dueDate,
      'Status': status,
    });
    final res = await _client.post('/EmployeeApp/AssignTask', form: form);
    final data = res.data as Map<String, dynamic>;
    if (!(data['message']?.toString().toLowerCase() == 'success')) {
      throw ApiException(extractMessage(data, 'Could not assign task.'));
    }
  }

  Future<void> updateTaskStatusAdmin(int id, int status) async {
    final res = await _client.post('/EmployeeApp/UpdateTaskStatusAdmin', data: {'id': id, 'status': status});
    final data = res.data as Map<String, dynamic>;
    if (data['message'] != 'success') {
      throw ApiException(extractMessage(data, 'Could not update task status.'));
    }
  }

  Future<void> deleteTask(int id) async {
    final res = await _client.post('/EmployeeApp/DeleteTask', data: {'id': id});
    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ApiException('Could not delete task.');
    }
  }
}
