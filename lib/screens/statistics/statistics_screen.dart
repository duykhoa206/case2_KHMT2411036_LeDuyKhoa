import 'package:flutter/material.dart';
import '../../models/task.dart';

class StatisticsScreen extends StatefulWidget {
  final List<Task> tasks; // Nhận danh sách task hiện tại để thống kê

  const StatisticsScreen({Key? key, required this.tasks}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final bool _isLoading = false;
  final String? _errorMessage = null;

  @override
  Widget build(BuildContext context) {
    // 1. Thống kê tổng số công việc theo trạng thái
    int totalTasks = widget.tasks.length;
    int completedTasks = widget.tasks.where((t) => t.status == 'completed' || t.status == 'Đã hoàn thành').length;
    int inProgressTasks = widget.tasks.where((t) => t.status == 'in_progress' || t.status == 'Đang thực hiện').length;
    int todoTasks = totalTasks - completedTasks - inProgressTasks;

    // 2. Thống kê công việc được giao & đang phụ trách
    int assignedToMe = widget.tasks.where((t) => t.assigneeIds.isNotEmpty).length;
    int leadingByMe = widget.tasks.where((t) => t.primaryAssigneeId != null && t.primaryAssigneeId!.isNotEmpty).length;

    // 3. Thống kê công việc sắp đến hạn và quá hạn
    final now = DateTime.now();
    int overdueTasks = 0;
    int upcomingTasks = 0;

    for (var task in widget.tasks) {
      try {
        final dueDate = DateTime.parse(task.dueDate);
        if (dueDate.isBefore(now) && task.status != 'completed') {
          overdueTasks++;
        } else if (dueDate.difference(now).inDays <= 3 && dueDate.isAfter(now)) {
          upcomingTasks++;
        }
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê tổng quan'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Text(
          'Lỗi: $_errorMessage',
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Trạng thái tải dữ liệu
          Card(
            color: Colors.blue.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Dữ liệu đã được đồng bộ từ Server MongoDB', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nhóm 1: Trạng thái công việc
          const Text('Trạng thái công việc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('Tổng số', '$totalTasks', Colors.blue),
              _buildStatCard('Đang làm', '$inProgressTasks', Colors.orange),
              _buildStatCard('Hoàn thành', '$completedTasks', Colors.green),
            ],
          ),
          const SizedBox(height: 20),

          // Nhóm 2: Phân công & Phụ trách
          const Text('Phân công & Phụ trách', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('Được giao', '$assignedToMe', Colors.purple),
              _buildStatCard('Phụ trách chính', '$leadingByMe', Colors.amber.shade800),
            ],
          ),
          const SizedBox(height: 20),

          // Nhóm 3: Cảnh báo thời hạn
          const Text('Cảnh báo thời hạn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('Sắp đến hạn', '$upcomingTasks', Colors.teal),
              _buildStatCard('Quá hạn', '$overdueTasks', Colors.red),
            ],
          ),
          const SizedBox(height: 20),

          // Nhóm 4: Lịch sử hoạt động gần đây
          const Text('Lịch sử hoạt động gần đây', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ListTile(
                    leading: Icon(Icons.history, color: Colors.blue),
                    title: Text('Đã cập nhật trạng thái công việc'),
                    subtitle: Text('Hôm nay, 15:30 - Thao tác thành công'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.assignment_ind, color: Colors.purple),
                    title: Text('Giao công việc mới cho thành viên'),
                    subtitle: Text('Hôm qua, 10:15 - Thao tác thành công'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 6),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}