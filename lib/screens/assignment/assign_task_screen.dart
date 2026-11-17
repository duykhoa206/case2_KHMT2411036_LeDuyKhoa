import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/user_service.dart';
import '../notifications/notification_screen.dart';
import '../tasks/task_list_screen.dart';

class AssignTaskScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const AssignTaskScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _searchController = TextEditingController();

  List<Map<String, String>> _allUsers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _selectedUserIds = [];
  String? _mainAssigneeId;

  @override
  void initState() {
    super.initState();
    final existingAssignees = widget.task['assigneeIds'];
    if (existingAssignees is List) {
      for (final item in existingAssignees) {
        final idStr = item.toString().trim();
        if (idStr.isNotEmpty && !_selectedUserIds.contains(idStr)) {
          _selectedUserIds.add(idStr);
        }
      }
    }
    final existingMain = widget.task['primaryAssigneeId']?.toString().trim();
    if (existingMain != null && existingMain.isNotEmpty) {
      _mainAssigneeId = existingMain;
    }

    _loadUsers();
  }

  Future<void> _loadUsers({String query = ''}) async {
    setState(() => _isLoading = true);
    final users = await UserService.fetchUsers(searchQuery: query);
    if (!mounted) return;
    setState(() {
      _allUsers = users;
      // Nếu danh sách cũ đang lưu theo email thì tự động map sang id để hiện dấu tích
      for (final u in _allUsers) {
        final uid = (u['id'] ?? '').trim();
        final uemail = (u['email'] ?? '').trim().toLowerCase();
        if (_selectedUserIds.any((x) => x.toLowerCase() == uemail) &&
            uid.isNotEmpty &&
            !_selectedUserIds.contains(uid)) {
          _selectedUserIds.add(uid);
        }
        if (_mainAssigneeId != null &&
            _mainAssigneeId!.toLowerCase() == uemail &&
            uid.isNotEmpty) {
          _mainAssigneeId = uid;
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _saveAssignment(String taskTitle) async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một người nhận việc!'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final String taskId =
    (widget.task['id'] ?? widget.task['_id'] ?? '').toString().trim();
    final String taskTitleKey =
    (widget.task['title'] ?? '').toString().trim();
    final String nowIso = DateTime.now().toIso8601String();

    // Gom cả ID và Email của những người được chọn để bên tài khoản kia đối chiếu kiểu gì cũng khớp
    final Set<String> combinedAssignees = {};
    for (final selectedId in _selectedUserIds) {
      combinedAssignees.add(selectedId.trim());
      final matchedUser =
      _allUsers.where((u) => u['id'] == selectedId).toList();
      if (matchedUser.isNotEmpty) {
        final email = (matchedUser.first['email'] ?? '').trim();
        if (email.isNotEmpty) {
          combinedAssignees.add(email);
        }
      }
    }

    final List<String> finalAssigneeList = combinedAssignees.toList();

    // Lấy cả tên và email của người phụ trách chính
    String primaryName = 'Đã chỉ định';
    String primaryEmail = _mainAssigneeId ?? '';
    final mainUserMatch =
    _allUsers.where((u) => u['id'] == _mainAssigneeId).toList();
    if (mainUserMatch.isNotEmpty) {
      primaryName = mainUserMatch.first['name'] ?? 'Đã chỉ định';
      primaryEmail = mainUserMatch.first['email'] ?? _mainAssigneeId!;
    }

    final overrideData = {
      'assigneeIds': finalAssigneeList,
      'primaryAssigneeId': _mainAssigneeId,
      'primaryAssigneeEmail': primaryEmail,
      'primaryAssigneeName': primaryName,
    };

    // 1. Lưu vào bộ nhớ đệm theo cả ID và Title để không bao giờ bị trượt key
    if (taskId.isNotEmpty) {
      TaskListScreen.assignmentOverrides[taskId] = overrideData;
    }
    if (taskTitleKey.isNotEmpty) {
      TaskListScreen.assignmentOverrides[taskTitleKey] = overrideData;
    }

    // 2. Gọi API PUT/PATCH lưu phân công xuống MongoDB
    if (taskId.isNotEmpty) {
      final updatedTaskPayload = {
        ...widget.task,
        'assigneeIds': finalAssigneeList,
        'primaryAssigneeId': _mainAssigneeId,
        'updatedAt': nowIso,
      };

      try {
        final putRes = await http.put(
          Uri.parse('http://10.0.2.2:3000/api/tasks/$taskId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updatedTaskPayload),
        );

        if (putRes.statusCode != 200) {
          await http.patch(
            Uri.parse('http://10.0.2.2:3000/api/tasks/$taskId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'assigneeIds': finalAssigneeList,
              'primaryAssigneeId': _mainAssigneeId,
              'updatedAt': nowIso,
            }),
          );
        }
      } catch (e) {
        debugPrint('Lưu phân công cục bộ: $e');
      }
    }

    // 3. Gửi thông báo cho người được giao
    for (final target in finalAssigneeList) {
      NotificationScreen.addNotification(
        recipientId: target,
        title: 'Giao công việc mới',
        body: 'Bạn được giao công việc: "$taskTitle"',
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Giao công việc thành công!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context, overrideData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskTitle = widget.task['title'] ?? 'Công việc không có tiêu đề';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao công việc'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Công việc: $taskTitle',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Tìm người theo tên hoặc email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _loadUsers(query: value);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn người nhận việc:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allUsers.isEmpty
                  ? const Center(
                child: Text(
                  'Không tìm thấy người dùng phù hợp trong hệ thống.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: _allUsers.length,
                itemBuilder: (context, index) {
                  final user = _allUsers[index];
                  final userId = user['id']!;
                  final userEmail =
                  (user['email'] ?? '').toLowerCase();
                  final isSelected = _selectedUserIds.contains(userId) ||
                      _selectedUserIds
                          .any((e) => e.toLowerCase() == userEmail);
                  final isMain = _mainAssigneeId == userId ||
                      (_mainAssigneeId != null &&
                          _mainAssigneeId!.toLowerCase() == userEmail);

                  return CheckboxListTile(
                    title: Text(user['name']!),
                    subtitle: Text(user['email']!),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          if (!_selectedUserIds.contains(userId)) {
                            _selectedUserIds.add(userId);
                          }
                          _mainAssigneeId ??= userId;
                        } else {
                          _selectedUserIds.removeWhere((item) =>
                          item == userId ||
                              item.toLowerCase() == userEmail);
                          if (_mainAssigneeId == userId ||
                              (_mainAssigneeId != null &&
                                  _mainAssigneeId!.toLowerCase() ==
                                      userEmail)) {
                            _mainAssigneeId =
                            _selectedUserIds.isNotEmpty
                                ? _selectedUserIds.first
                                : null;
                          }
                        }
                      });
                    },
                    secondary: isSelected
                        ? IconButton(
                      icon: Icon(
                        isMain ? Icons.star : Icons.star_border,
                        color:
                        isMain ? Colors.amber : Colors.grey,
                      ),
                      tooltip: 'Chọn làm người phụ trách chính',
                      onPressed: () {
                        setState(() {
                          _mainAssigneeId = userId;
                        });
                      },
                    )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isSaving ? null : () => _saveAssignment(taskTitle),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Xác nhận giao việc',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}