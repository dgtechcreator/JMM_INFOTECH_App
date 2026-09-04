import 'package:flutter/material.dart';

import '../../core/date_format.dart';
import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = AppNotificationService();
  List<NotificationItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.getMyNotifications();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _markAllRead() async {
    await _service.markAllRead();
    _load();
  }

  Future<void> _onTap(NotificationItem item) async {
    if (!item.isRead) {
      await _service.markRead(item.notificationId);
      _load();
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'Leave':
        return Icons.event_available_outlined;
      case 'Reimbursement':
        return Icons.receipt_long_outlined;
      case 'Salary':
        return Icons.account_balance_wallet_outlined;
      case 'Attendance':
        return Icons.fingerprint;
      case 'Task':
        return Icons.checklist_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: _items.any((i) => !i.isRead) ? _markAllRead : null, child: const Text('Mark all read')),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _items.isEmpty
              ? const EmptyState(message: 'No notifications yet.', icon: Icons.notifications_none_rounded)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _onTap(item),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.isRead ? AppColors.surface : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_iconFor(item.notifyType), color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    if (item.message != null && item.message!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(item.message!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(formatDateTime(item.createdOn), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              if (!item.isRead)
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
