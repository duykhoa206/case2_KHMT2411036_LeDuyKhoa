import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/user_service.dart';
import '../notifications/notification_screen.dart';
import '../tasks/task_list_screen.dart';

class TaskSharingScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const TaskSharingScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskSharingScreen> createState() => _TaskSharingScreenState();
}

class _TaskSharingScreenState extends State<TaskSharingScreen> {
  List _allUsers = [];
  List _sharedList = [];
  bool _isLoading = true;

  String get _taskId =>
      (widget.task['id'] ?? widget.task['_id'] ?? '').toString().trim();
  String get _taskTitle =>
      (widget.task['title'] ?? 'Công việc').toString().trim();

  @override
  void initState() {
    super.initState();
    _initSharingData();
  }

  Future<void> _initSharingData() async {
    final users = await UserService.fetchUsers();

    final dynamic existing = (_taskId.isNotEmpty
        ? TaskListScreen.sharedOverrides[_taskId]
        : null) ??
        TaskListScreen.sharedOverrides[_taskTitle];

    if (!mounted) return;
    setState(() {
      _allUsers = users;
      if (existing is List) {
        _sharedList = existing
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _sharedList = [];
      }
      _isLoading = false;
    });
  }

  void _syncShares() {
    final List copyList = _sharedList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (_taskId.isNotEmpty) {
      TaskListScreen.sharedOverrides[_taskId] = copyList;
    }
    if (_taskTitle.isNotEmpty) {
      TaskListScreen.sharedOverrides[_taskTitle] = copyList;
    }

    if (_taskId.isNotEmpty) {
      http
          .put(
        Uri.parse('http://10.0.2.2:3000/api/tasks/$_taskId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          ...widget.task,
          'sharedWith': copyList,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      )
          .catchError((_) => http.Response('', 500));
    }
  }

  void _showAddShareDialog() {
    if (_allUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy danh sách người dùng!')),
      );
      return;
    }

    int selectedIndex = 0;
    String selectedRole = 'viewer';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Thêm người chia sẻ'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedIndex,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chọn người nhận',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(_allUsers.length, (i) {
                      final u = _allUsers[i];
                      final uname =
                      (u['name'] ?? u['fullName'] ?? '').toString();
                      final uemail = (u['email'] ?? '').toString();
                      return DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          '$uname ($uemail)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedIndex = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Quyền hạn',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'viewer',
                        child: Text('Xem (Viewer)'),
                      ),
                      DropdownMenuItem(
                        value: 'editor',
                        child: Text('Chỉnh sửa (Editor)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedRole = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final userObj = _allUsers[selectedIndex];
                    final uid =
                    (userObj['id'] ?? userObj['_id'] ?? '').toString().trim();
                    final uname =
                    (userObj['name'] ?? userObj['fullName'] ?? '')
                        .toString()
                        .trim();
                    final uemail =
                    (userObj['email'] ?? '').toString().trim();

                    Navigator.of(dialogContext).pop();

                    setState(() {
                      final index = _sharedList.indexWhere((item) =>
                      (uemail.isNotEmpty &&
                          (item['email'] ?? '')
                              .toString()
                              .toLowerCase() ==
                              uemail.toLowerCase()) ||
                          (uid.isNotEmpty && item['userId'] == uid));

                      if (index >= 0) {
                        _sharedList[index]['role'] = selectedRole;
                      } else {
                        _sharedList.add({
                          'userId': uid,
                          'name': uname,
                          'email': uemail,
                          'role': selectedRole,
                        });
                      }
                    });

                    _syncShares();

                    // Gửi thông báo kèm cả ID, Email và Tên để tài khoản nhận thấy ngay lập tức
                    final roleLabel = selectedRole == 'editor'
                        ? 'Chỉnh sửa (Editor)'
                        : 'Xem (Viewer)';
                    NotificationScreen.addNotification(
                      recipientIds: [uid, uemail, uname],
                      title: 'Chia sẻ công việc mới',
                      body:
                      'Bạn được chia sẻ công việc "$_taskTitle" với quyền $roleLabel.',
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã chia sẻ công việc và gửi thông báo!'),
                      ),
                    );
                  },
                  child: const Text('Chia sẻ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý chia sẻ'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Công việc: $_taskTitle',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Danh sách người được chia sẻ và quyền truy cập:',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sharedList.isEmpty
                  ? const Center(
                child: Text(
                  'Chưa có ai được chia sẻ công việc này.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: _sharedList.length,
                itemBuilder: (context, index) {
                  final item = _sharedList[index];
                  final role = (item['role'] ?? 'viewer').toString();
                  final isEditor =
                  role.toLowerCase().contains('editor');

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      title: Text(
                        (item['name'] ?? '').toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle:
                      Text((item['email'] ?? '').toString()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isEditor
                                  ? Colors.orange.shade100
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isEditor ? 'editor' : 'viewer',
                              style: TextStyle(
                                color: isEditor
                                    ? Colors.orange.shade900
                                    : Colors.blue.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              final targetUid =
                              (item['userId'] ?? '').toString();
                              final targetEmail =
                              (item['email'] ?? '').toString();
                              final targetName =
                              (item['name'] ?? '').toString();

                              setState(() {
                                if (val == 'remove') {
                                  _sharedList.removeAt(index);
                                } else {
                                  _sharedList[index]['role'] = val;
                                }
                              });
                              _syncShares();

                              if (val != 'remove') {
                                final newRoleLabel = val == 'editor'
                                    ? 'Chỉnh sửa (Editor)'
                                    : 'Xem (Viewer)';
                                NotificationScreen.addNotification(
                                  recipientIds: [
                                    targetUid,
                                    targetEmail,
                                    targetName
                                  ],
                                  title: 'Cập nhật quyền chia sẻ',
                                  body:
                                  'Quyền của bạn trong công việc "$_taskTitle" đã đổi thành $newRoleLabel.',
                                );
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'viewer',
                                child: Text(
                                    'Đổi thành Viewer (Chỉ xem)'),
                              ),
                              const PopupMenuItem(
                                value: 'editor',
                                child: Text(
                                    'Đổi thành Editor (Chỉnh sửa)'),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  'Xóa quyền chia sẻ',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        onPressed: _showAddShareDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}