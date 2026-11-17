import 'package:flutter/material.dart';

class TaskCreateScreen extends StatefulWidget {
  final String userEmail; // Thêm nhận email người dùng đăng nhập

  const TaskCreateScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends State<TaskCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _priority = 'medium'; // low, medium, high
  String _status = 'todo';     // todo, in_progress, completed

  DateTime? _startDate;
  DateTime? _dueDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo mới công việc'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 1. Tên công việc (title)
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tên công việc *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên công việc';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2. Mô tả (description)
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả chi tiết',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Ngày bắt đầu & Hạn hoàn thành
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_startDate == null
                          ? 'Ngày bắt đầu'
                          : '${_startDate!.toLocal()}'.split(' ')[0]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, false),
                      icon: const Icon(Icons.event_available),
                      label: Text(_dueDate == null
                          ? 'Hạn hoàn thành *'
                          : '${_dueDate!.toLocal()}'.split(' ')[0]),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _dueDate == null ? Colors.red : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Mức độ ưu tiên
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Mức độ ưu tiên',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Thấp (Low)')),
                  DropdownMenuItem(value: 'medium', child: Text('Trung bình (Medium)')),
                  DropdownMenuItem(value: 'high', child: Text('Cao (High)')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _priority = value);
                },
              ),
              const SizedBox(height: 16),

              // 5. Trạng thái ban đầu
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái ban đầu',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'todo', child: Text('Chưa thực hiện (Todo)')),
                  DropdownMenuItem(value: 'in_progress', child: Text('Đang thực hiện (In Progress)')),
                  DropdownMenuItem(value: 'completed', child: Text('Đã hoàn thành (Completed)')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 32),

              // Nút xác nhận tạo
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    if (_dueDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng chọn hạn hoàn thành!')),
                      );
                      return;
                    }

                    // Đóng gói dữ liệu với createdBy chính là tài khoản đang đăng nhập
                    final newTask = {
                      'title': _titleController.text.trim(),
                      'description': _descriptionController.text.trim(),
                      'createdBy': widget.userEmail, // LẤY CHÍNH XÁC EMAIL/TÊN ĐĂNG NHẬP
                      'assigneeIds': [widget.userEmail],
                      'primaryAssigneeId': widget.userEmail,
                      'startDate': _startDate != null ? '${_startDate!.toLocal()}'.split(' ')[0] : null,
                      'dueDate': '${_dueDate!.toLocal()}'.split(' ')[0],
                      'priority': _priority,
                      'status': _status,
                      'createdAt': DateTime.now().toIso8601String(),
                      'updatedAt': DateTime.now().toIso8601String(),
                    };

                    Navigator.pop(context, newTask);
                  }
                },
                child: const Text('Xác nhận tạo công việc', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}