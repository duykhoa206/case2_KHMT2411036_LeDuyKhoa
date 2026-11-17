import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/task.dart';
import '../../services/user_service.dart';
import '../assignment/assign_task_screen.dart';
import '../sharing/task_sharing_screen.dart';
import 'task_edit_screen.dart';
import 'task_list_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  static final Map<String, String> statusOverrides = {};

  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _currentTask;
  String _primaryAssigneeName = 'Chưa chỉ định';
  bool _hasUpdated = false;
  String _myUserId = '';

  @override
  void initState() {
    super.initState();
    final savedStatus = TaskDetailScreen.statusOverrides[widget.task.id] ??
        TaskDetailScreen.statusOverrides[widget.task.title];
    _currentTask = savedStatus != null
        ? Task(
      id: widget.task.id,
      title: widget.task.title,
      description: widget.task.description,
      createdBy: widget.task.createdBy,
      assigneeIds: widget.task.assigneeIds,
      primaryAssigneeId: widget.task.primaryAssigneeId,
      startDate: widget.task.startDate,
      dueDate: widget.task.dueDate,
      priority: widget.task.priority,
      status: savedStatus,
      createdAt: widget.task.createdAt,
      updatedAt: widget.task.updatedAt,
    )
        : widget.task;

    _loadUsersAndAssigneeInfo();
  }

  Future<void> _loadUsersAndAssigneeInfo() async {
    final myEmail = TaskListScreen.activeUserEmail.toLowerCase();
    final primaryId = _currentTask.primaryAssigneeId;

    try {
      final users = await UserService.fetchUsers();

      final me = users.where(
            (u) => (u['email'] ?? '').toString().trim().toLowerCase() == myEmail,
      );
      if (me.isNotEmpty) {
        _myUserId = (me.first['id'] ?? me.first['_id'] ?? '').toString().trim();
      }

      if (primaryId != null && primaryId.isNotEmpty) {
        final match = users.where(
              (u) =>
          u['id'] == primaryId ||
              u['_id'] == primaryId ||
              u['email'] == primaryId,
        );
        if (match.isNotEmpty) {
          _primaryAssigneeName =
              (match.first['fullName'] ?? match.first['name'] ?? primaryId)
                  .toString();
        }
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  bool get _isViewerOnly {
    final myEmail = TaskListScreen.activeUserEmail.trim().toLowerCase();
    if (myEmail.isEmpty) return false;
    final myUsername = myEmail.split('@').first;
    final myId = _myUserId.toLowerCase();

    // 1. Người tạo có toàn quyền
    final creator = _currentTask.createdBy.trim().toLowerCase();
    if (creator == myEmail ||
        creator == myUsername ||
        (myId.isNotEmpty && creator == myId)) {
      return false;
    }

    // 2. Người được Giao việc có quyền cập nhật
    final primary = (_currentTask.primaryAssigneeId ?? '').trim().toLowerCase();
    final assignees =
    _currentTask.assigneeIds.map((e) => e.trim().toLowerCase()).toList();
    if (assignees.contains(myEmail) ||
        assignees.contains(myUsername) ||
        (myId.isNotEmpty && assignees.contains(myId)) ||
        (primary.isNotEmpty &&
            (primary == myEmail ||
                primary == myUsername ||
                (myId.isNotEmpty && primary == myId)))) {
      return false;
    }

    // 3. Kiểm tra quyền trong danh sách Chia sẻ
    final dynamic rawShared =
        TaskListScreen.sharedOverrides[_currentTask.id] ??
            TaskListScreen.sharedOverrides[_currentTask.title];
    final List sharedUsers = rawShared is List ? rawShared : [];

    for (final u in sharedUsers) {
      if (u is Map) {
        final sId = (u['userId'] ?? '').toString().trim().toLowerCase();
        final sEmail = (u['email'] ?? '').toString().trim().toLowerCase();
        final sName = (u['name'] ?? '').toString().trim().toLowerCase();
        final sRole = (u['role'] ?? '').toString().toLowerCase();

        final isMatch = sEmail == myEmail ||
            sEmail.split('@').first == myUsername ||
            sName == myUsername ||
            (myId.isNotEmpty && sId == myId);

        if (isMatch) {
          if (sRole.contains('editor') || sRole.contains('chỉnh sửa')) {
            return false;
          }
          return true; // Quyền viewer -> Khóa sửa/xóa
        }
      }
    }

    return true;
  }

  Future<void> _updateTaskProgress(String newStatus) async {
    final String nowIso = DateTime.now().toIso8601String();

    final updatedTask = Task(
      id: _currentTask.id,
      title: _currentTask.title,
      description: _currentTask.description,
      createdBy: _currentTask.createdBy,
      assigneeIds: _currentTask.assigneeIds,
      primaryAssigneeId: _currentTask.primaryAssigneeId,
      startDate: _currentTask.startDate,
      dueDate: _currentTask.dueDate,
      priority: _currentTask.priority,
      status: newStatus,
      createdAt: _currentTask.createdAt,
      updatedAt: nowIso,
    );

    TaskDetailScreen.statusOverrides[_currentTask.id] = newStatus;
    TaskDetailScreen.statusOverrides[_currentTask.title] = newStatus;

    final Map<String, dynamic> fullPayload = {
      ...updatedTask.toJson(),
      'status': newStatus,
      'updatedAt': nowIso,
    };

    try {
      final putRes = await http.put(
        Uri.parse('http://10.0.2.2:3000/api/tasks/${_currentTask.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(fullPayload),
      );

      if (putRes.statusCode != 200) {
        await http.patch(
          Uri.parse('http://10.0.2.2:3000/api/tasks/${_currentTask.id}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'status': newStatus, 'updatedAt': nowIso}),
        );
      }
    } catch (e) {
      debugPrint('Cập nhật tiến độ cục bộ: $e');
    }

    if (!mounted) return;
    setState(() {
      _hasUpdated = true;
      _currentTask = updatedTask;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text('Đã cập nhật tiến độ sang "${_getStatusLabel(newStatus)}"!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showUpdateProgressDialog() {
    String selectedStatus = _currentTask.status;
    if (selectedStatus != 'todo' &&
        selectedStatus != 'in_progress' &&
        selectedStatus != 'completed') {
      selectedStatus = 'todo';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cập nhật tiến độ'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Chưa bắt đầu (todo)'),
                    secondary: const Icon(Icons.radio_button_unchecked,
                        color: Colors.grey),
                    value: 'todo',
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedStatus = value);
                      }
                    },
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Đang thực hiện (in_progress)'),
                    secondary:
                    const Icon(Icons.timelapse, color: Colors.orange),
                    value: 'in_progress',
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedStatus = value);
                      }
                    },
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Đã hoàn thành (completed)'),
                    secondary:
                    const Icon(Icons.check_circle, color: Colors.green),
                    value: 'completed',
                    groupValue: selectedStatus,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedStatus = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _updateTaskProgress(selectedStatus);
                  },
                  child: const Text('Lưu thay đổi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTask() async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:3000/api/tasks/${_currentTask.id}'),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa công việc thành công!')),
        );
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa công việc thất bại từ server!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa công việc khỏi danh sách!')),
      );
      Navigator.pop(context, true);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa công việc này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteTask();
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'completed':
      case 'Đã hoàn thành':
        return 'completed (Đã hoàn thành)';
      case 'in_progress':
      case 'Đang thực hiện':
        return 'in_progress (Đang thực hiện)';
      default:
        return 'todo (Chưa bắt đầu)';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
      case 'Đã hoàn thành':
        return Colors.green;
      case 'in_progress':
      case 'Đang thực hiện':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_currentTask.status);
    final bool isViewer = _isViewerOnly;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasUpdated);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasUpdated),
          ),
          actions: isViewer
              ? []
              : [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Chỉnh sửa',
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TaskEditScreen(task: _currentTask),
                  ),
                );
                if (updated == true && mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Xóa công việc',
              onPressed: _confirmDelete,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              Text(
                _currentTask.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  InkWell(
                    onTap: isViewer ? null : _showUpdateProgressDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Trạng thái: ${_currentTask.status}',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!isViewer) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.edit, size: 14, color: statusColor),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ưu tiên: ${_currentTask.priority}',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 30, thickness: 1),
              const Text(
                'Mô tả công việc:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blueAccent),
              ),
              const SizedBox(height: 6),
              Text(
                _currentTask.description.isEmpty
                    ? 'Không có mô tả chi tiết.'
                    : _currentTask.description,
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              const Text(
                'Thời gian:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blueAccent),
              ),
              const SizedBox(height: 6),
              if (_currentTask.startDate != null)
                Text('• Ngày bắt đầu: ${_currentTask.startDate}',
                    style: const TextStyle(fontSize: 14)),
              Text('• Hạn hoàn thành: ${_currentTask.dueDate}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const Divider(height: 30, thickness: 1),
              const Text(
                'Nhân sự tham gia:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blueAccent),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.blue),
                title: const Text('Người tạo'),
                subtitle: Text(_currentTask.createdBy.isEmpty
                    ? 'Lê Duy Khoa'
                    : _currentTask.createdBy),
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Người phụ trách chính'),
                subtitle: Text(
                  (_currentTask.primaryAssigneeId != null &&
                      _currentTask.primaryAssigneeId!.isNotEmpty)
                      ? _primaryAssigneeName
                      : 'Chưa chỉ định',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const Divider(height: 30, thickness: 1),
              if (isViewer)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.visibility_outlined, color: Colors.blueGrey),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bạn được chia sẻ công việc này với quyền Xem (Viewer). Không thể chỉnh sửa hoặc xóa.',
                          style: TextStyle(
                              color: Colors.blueGrey,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                const Text(
                  'Hành động quản lý:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blueAccent),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _showUpdateProgressDialog,
                    icon: const Icon(Icons.trending_up),
                    label: const Text(
                      'Cập nhật tiến độ',
                      style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AssignTaskScreen(
                                  task: {
                                    ..._currentTask.toJson(),
                                    'id': _currentTask.id,
                                  }),
                            ),
                          );

                          if (result != null && result is Map) {
                            setState(() {
                              _hasUpdated = true;
                              _currentTask = Task(
                                id: _currentTask.id,
                                title: _currentTask.title,
                                description: _currentTask.description,
                                createdBy: _currentTask.createdBy,
                                assigneeIds: List<String>.from(
                                    result['assigneeIds'] ?? []),
                                primaryAssigneeId:
                                result['primaryAssigneeId']?.toString(),
                                startDate: _currentTask.startDate,
                                dueDate: _currentTask.dueDate,
                                priority: _currentTask.priority,
                                status: _currentTask.status,
                                createdAt: _currentTask.createdAt,
                                updatedAt: _currentTask.updatedAt,
                              );
                              _primaryAssigneeName =
                                  (result['primaryAssigneeName'] ??
                                      'Đã chỉ định')
                                      .toString();
                            });

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Đã cập nhật phân công!')),
                            );
                          }
                        },
                        icon: const Icon(Icons.assignment_ind),
                        label: const Text('Giao việc'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TaskSharingScreen(
                                  task: {
                                    ..._currentTask.toJson(),
                                    'id': _currentTask.id,
                                  }),
                            ),
                          );
                          setState(() {
                            _hasUpdated = true;
                          });
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Quản lý chia sẻ'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa công việc này',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}