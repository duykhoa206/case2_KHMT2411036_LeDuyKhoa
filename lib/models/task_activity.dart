class TaskActivity {
  final String id;
  final String taskId;
  final String userId;
  final String action;
  final Map<String, dynamic> details;
  final String createdAt;

  TaskActivity({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.action,
    required this.details,
    required this.createdAt,
  });

  factory TaskActivity.fromJson(Map<String, dynamic> json) {
    return TaskActivity(
      id: json['_id'] ?? json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      userId: json['userId'] ?? '',
      action: json['action'] ?? '',
      details: json['details'] != null ? Map<String, dynamic>.from(json['details']) : {},
      createdAt: json['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'userId': userId,
      'action': action,
      'details': details,
    };
  }
}