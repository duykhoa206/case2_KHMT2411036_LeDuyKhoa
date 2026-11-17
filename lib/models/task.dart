class Task {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final List<String> assigneeIds;
  final String? primaryAssigneeId;
  final String? startDate;
  final String dueDate;
  final String priority; // low, medium, high
  final String status; // todo, in_progress, completed
  final String createdAt;
  final String updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.assigneeIds,
    this.primaryAssigneeId,
    this.startDate,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdBy: json['createdBy'] ?? '',
      assigneeIds: json['assigneeIds'] != null
          ? List<String>.from(json['assigneeIds'])
          : [],
      primaryAssigneeId: json['primaryAssigneeId'],
      startDate: json['startDate'],
      dueDate: json['dueDate'] ?? '',
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'todo',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'assigneeIds': assigneeIds,
      'primaryAssigneeId': primaryAssigneeId,
      'startDate': startDate,
      'dueDate': dueDate,
      'priority': priority,
      'status': status,
    };
  }
}