import '../core/api_client.dart';
import '../models/models.dart';

class AppNotificationService {
  final _client = ApiClient.instance;

  Future<List<NotificationItem>> getMyNotifications() async {
    final res = await _client.get('/EmployeeApp/GetMyNotifications');
    return (res.data as List).cast<Map<String, dynamic>>().map(NotificationItem.fromJson).toList();
  }

  Future<int> getUnreadCount() async {
    final res = await _client.get('/EmployeeApp/GetUnreadNotificationCount');
    return (res.data as Map<String, dynamic>)['count'] as int? ?? 0;
  }

  Future<void> markRead(int id) async {
    await _client.post('/EmployeeApp/MarkNotificationRead', data: {'id': id});
  }

  Future<void> markAllRead() async {
    await _client.post('/EmployeeApp/MarkAllNotificationsRead');
  }
}
