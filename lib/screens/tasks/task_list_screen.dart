import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/task.dart';
import '../../services/user_service.dart';
import '../profile/profile_screen.dart';
import '../notifications/notification_screen.dart';
import '../statistics/statistics_screen.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  final String userEmail;

  // Dùng Map<String, dynamic> đơn giản để tránh lỗi cú pháp lồng nhau
  static final Map<String, dynamic> assignmentOverrides = {};
  static final Map<String, dynamic> sharedOverrides = {};
  static String activeUserEmail = '';

  const TaskListScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  int _currentIndex = 0;

  String _sortBy = 'dueDate';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Task> _tasks = [];
  bool _isLoading = true;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    TaskListScreen.activeUserEmail = widget.userEmail.trim();
    _initData();
  }

  Future<void> _initData() async {
    await _loadCurrentUserId();
    await _fetchTasksFromDatabase();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final users = await UserService.fetchUsers();
      final me = users
          .where((u) =>
      (u['email'] ?? '').toString().trim().toLowerCase() ==
          widget.userEmail.trim().toLowerCase())
          .toList();
      if (me.isNotEmpty && mounted) {
        setState(() {
          _currentUserId =
              (me.first['id'] ?? me.first['_id'] ?? '').toString().trim();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchTasksFromDatabase() async {
    try {
      final response =
      await http.get(Uri.parse('http://10.0.2.2:3000/api/tasks'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List tasksJson = data['data'];
          if (!mounted) return;
          setState(() {
            _tasks = tasksJson.map((jsonItem) {
              final t = Task.fromJson(jsonItem);

              if (jsonItem is Map && jsonItem['sharedWith'] is List) {
                final List rawShared = jsonItem['sharedWith'];
                if (rawShared.isNotEmpty &&
                    !TaskListScreen.sharedOverrides.containsKey(t.id)) {
                  TaskListScreen.sharedOverrides[t.id] = rawShared;
                }
              }

              final savedStatus = TaskDetailScreen.statusOverrides[t.id] ??
                  TaskDetailScreen.statusOverrides[t.title];
              final dynamic savedAssign =
                  TaskListScreen.assignmentOverrides[t.id] ??
                      TaskListScreen.assignmentOverrides[t.title];

              final Set<String> mergedAssignees = {
                ...t.assigneeIds.map((e) => e.trim()),
                if (savedAssign is Map && savedAssign['assigneeIds'] is List)
                  ...List<String>.from(savedAssign['assigneeIds'])
                      .map((e) => e.trim()),
              }..removeWhere((e) => e.isEmpty);

              return Task(
                id: t.id,
                title: t.title,
                description: t.description,
                createdBy: t.createdBy,
                assigneeIds: mergedAssignees.toList(),
                primaryAssigneeId: savedAssign is Map
                    ? (savedAssign['primaryAssigneeId']?.toString() ??
                    t.primaryAssigneeId)
                    : t.primaryAssigneeId,
                startDate: t.startDate,
                dueDate: t.dueDate,
                priority: t.priority,
                status: savedStatus ?? t.status,
                createdAt: t.createdAt,
                updatedAt: t.updatedAt,
              );
            }).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi kết nối lấy danh sách task: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createTaskOnServer(Map<String, dynamic> newTaskMap) async {
    try {
      if ((newTaskMap['createdBy'] ?? '').toString().trim().isEmpty) {
        newTaskMap['createdBy'] = widget.userEmail.trim();
      }

      final response = await http.post(
        Uri.parse('http://10.0.2.2:3000/api/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newTaskMap),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _fetchTasksFromDatabase();
      }
    } catch (e) {
      debugPrint('Lỗi tạo task lên server: $e');
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Tìm kiếm công việc...',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          )
              : const Text('Danh sách công việc'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  if (_isSearching) {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sắp xếp công việc',
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                });
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'dueDate', child: Text('Sắp xếp theo hạn chót')),
                const PopupMenuItem(
                    value: 'priority', child: Text('Sắp xếp theo độ ưu tiên')),
                const PopupMenuItem(
                    value: 'title', child: Text('Sắp xếp theo tiêu đề (A-Z)')),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Tất cả'),
              Tab(text: 'Của tôi'),
              Tab(text: 'Được giao'),
              Tab(text: 'Chia sẻ'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            _buildTaskListWidget('all'),
            _buildTaskListWidget('mine'),
            _buildTaskListWidget('assigned'),
            _buildTaskListWidget('shared'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final newTaskMap = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TaskCreateScreen(userEmail: widget.userEmail),
              ),
            );

            if (newTaskMap != null && newTaskMap is Map<String, dynamic>) {
              await _createTaskOnServer(newTaskMap);
            }
          },
          backgroundColor: Colors.blueAccent,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationScreen(
                    currentUserId: _currentUserId.isNotEmpty
                        ? _currentUserId
                        : widget.userEmail,
                    tasks: _tasks,
                  ),
                ),
              );
              return;
            }
            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatisticsScreen(tasks: _tasks),
                ),
              );
              return;
            }
            if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    userEmail: widget.userEmail,
                    tasks: _tasks,
                  ),
                ),
              );
              return;
            }
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'Công việc',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Thông báo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Thống kê',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListWidget(String filterType) {
    final String myEmail = widget.userEmail.trim().toLowerCase();
    final String myUsername = myEmail.split('@').first;
    final String myId = _currentUserId.trim().toLowerCase();

    final filteredTasks = _tasks.where((task) {
      bool matchesSearch = _searchQuery.isEmpty ||
          task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          task.description.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      final String creator = task.createdBy.trim().toLowerCase();
      final String primary =
      (task.primaryAssigneeId ?? '').trim().toLowerCase();
      final List<String> assignees =
      task.assigneeIds.map((e) => e.trim().toLowerCase()).toList();

      final bool isCreator = creator.isNotEmpty &&
          (creator == myEmail ||
              creator == myUsername ||
              (myId.isNotEmpty && creator == myId));

      final bool isAssignedToMe = assignees.contains(myEmail) ||
          assignees.contains(myUsername) ||
          (myId.isNotEmpty && assignees.contains(myId)) ||
          (primary.isNotEmpty &&
              (primary == myEmail ||
                  primary == myUsername ||
                  (myId.isNotEmpty && primary == myId)));

      final dynamic rawShared = TaskListScreen.sharedOverrides[task.id] ??
          TaskListScreen.sharedOverrides[task.title];
      final List sharedUsers = rawShared is List ? rawShared : [];

      final bool isSharedWithMe = sharedUsers.any((u) {
        if (u is! Map) return false;
        final sId = (u['userId'] ?? '').toString().trim().toLowerCase();
        final sEmail = (u['email'] ?? '').toString().trim().toLowerCase();
        final sName = (u['name'] ?? '').toString().trim().toLowerCase();
        return sEmail == myEmail ||
            sEmail.split('@').first == myUsername ||
            sName == myUsername ||
            (myId.isNotEmpty && sId == myId);
      });

      if (filterType == 'mine') {
        return isCreator;
      } else if (filterType == 'assigned') {
        return isAssignedToMe;
      } else if (filterType == 'shared') {
        return isSharedWithMe || (isCreator && sharedUsers.isNotEmpty);
      }

      return isCreator || isAssignedToMe || isSharedWithMe;
    }).toList();

    filteredTasks.sort((a, b) {
      if (_sortBy == 'dueDate') {
        return a.dueDate.compareTo(b.dueDate);
      } else if (_sortBy == 'priority') {
        const priorityOrder = {'high': 1, 'medium': 2, 'low': 3};
        int p1 = priorityOrder[a.priority] ?? 2;
        int p2 = priorityOrder[b.priority] ?? 2;
        return p1.compareTo(p2);
      } else {
        return a.title.compareTo(b.title);
      }
    });

    if (filteredTasks.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có công việc nào trong mục này.',
          style: TextStyle(color: Colors.grey, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredTasks.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        final statusColor = _getStatusColor(task.status);
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(
              task.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        task.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Hạn: ${task.dueDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskDetailScreen(task: task),
                ),
              );
              _fetchTasksFromDatabase();
            },
          ),
        );
      },
    );
  }
}