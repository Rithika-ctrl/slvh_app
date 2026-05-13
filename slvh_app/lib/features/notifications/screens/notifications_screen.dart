import 'package:flutter/material.dart';
import 'package:slvh_app/shared/widgets/empty_state_widget.dart';
import 'package:slvh_app/features/notifications/models/notification_model.dart';
import 'package:slvh_app/features/notifications/services/notification_service.dart';

/// Screen to display user notifications
class NotificationsScreen extends StatefulWidget {
  final String userId;

  const NotificationsScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.watchUserNotifications(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                userId: widget.userId,
                notificationService: _notificationService,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.notifications_off_outlined,
      title: 'No notifications',
      subtitle: 'You will receive notifications when your orders are updated',
      ),
    );
  }
}

/// Notification card widget
class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final String userId;
  final NotificationService notificationService;

  const _NotificationCard({
    required this.notification,
    required this.userId,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: _getStatusColor(),
              width: 4,
            ),
          ),
          color: notification.isRead ? Colors.white : Colors.blue[50],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          onTap: () {
            // Mark as read
            notificationService.markAsRead(userId, notification.id);

            // Navigate to order detail if available
            if (notification.orderId != null &&
                notification.orderId!.isNotEmpty) {
              // context.push('/order/${notification.orderId}');
            }
          },
          leading: _getNotificationIcon(),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(notification.body),
              const SizedBox(height: 4),
              Text(
                _formatDate(notification.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          trailing: PopupMenuButton(
            onSelected: (value) {
              if (value == 'delete') {
                notificationService.deleteNotification(userId, notification.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getNotificationIcon() {
    if (notification.orderStatus == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.notifications, color: Colors.blue[700]),
      );
    }

    final isOrderNotification =
        notification.orderStatus?.contains('Order') ?? false;
    if (isOrderNotification) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getStatusColor().withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getStatusIcon(),
          color: _getStatusColor(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.info, color: Colors.orange[700]),
    );
  }

  IconData _getStatusIcon() {
    switch (notification.orderStatus) {
      case 'Confirmed':
        return Icons.check_circle;
      case 'Preparing':
        return Icons.local_dining;
      case 'Ready for Pickup':
        return Icons.done_all;
      case 'Completed':
        return Icons.task_alt;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _getStatusColor() {
    switch (notification.orderStatus) {
      case 'Confirmed':
      case 'Ready for Pickup':
      case 'Completed':
        return Colors.green;
      case 'Preparing':
        return Colors.blue;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
