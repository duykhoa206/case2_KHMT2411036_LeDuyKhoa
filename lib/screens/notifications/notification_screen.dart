import 'package:flutter/material.dart';
import '../tasks/task_list_screen.dart';

class NotificationScreen extends StatefulWidget {
  final String? currentUserId;
  final List? tasks;

  const NotificationScreen({
    Key? key,
    this.currentUserId,
    this.tasks,
  }) : super(key: key);

  // Dùng List đơn giản không có ngoặc nhọn để không bao giờ bị lỗi copy
  static final List globalNotifications = [];

  static void addNotification({
    String? recipientId,
    List? recipientIds,
    required String title,
    required String body,
  }) {
    final now = TimeOfDay.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final List targets = [];
    if (recipientId != null && recipientId.trim().isNotEmpty) {
      targets.add(recipientId.trim().toLowerCase());
    }
    if (recipientIds != null) {
      for (final id in recipientIds) {
        final str = id.toString().trim().toLowerCase();
        if (str.isNotEmpty && !targets.contains(str)) {
          targets.add(str);
        }
      }
    }

    globalNotifications.insert(0, {
      'title': title,
      'body': body,
      'time': timeString,
      'targets': targets,
    });
  }

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    final String myId = (widget.currentUserId ?? '').trim().toLowerCase();
    final String myEmail = TaskListScreen.activeUserEmail.trim().toLowerCase();
    final String myUsername =
    myEmail.isNotEmpty ? myEmail.split('@').first : '';

    final List displayList =
    NotificationScreen.globalNotifications.where((item) {
      final List targets = (item['targets'] is List) ? item['targets'] : [];
      if (targets.isEmpty) return true;

      return targets.any((t) {
        final targetStr = t.toString().trim().toLowerCase();
        if (targetStr.isEmpty) return false;
        final targetUsername = targetStr.split('@').first;

        return (myId.isNotEmpty && targetStr == myId) ||
            (myEmail.isNotEmpty && targetStr == myEmail) ||
            (myUsername.isNotEmpty &&
                (targetStr == myUsername || targetUsername == myUsername));
      });
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          if (displayList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Xóa tất cả',
              onPressed: () {
                setState(() {
                  NotificationScreen.globalNotifications.clear();
                });
              },
            ),
        ],
      ),
      body: displayList.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 60, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Chưa có thông báo nào dành cho bạn.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: displayList.length,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          final item = displayList[index];
          return Card(
            elevation: 2,
            margin:
            const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.notifications_active,
                    color: Colors.white),
              ),
              title: Text(
                item['title']?.toString() ?? 'Thông báo mới',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(item['body']?.toString() ?? ''),
              trailing: Text(
                item['time']?.toString() ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }
}