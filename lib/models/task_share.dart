class TaskShare {
  final String id;
  final String taskId;
  final String userId;
  final String permission; // viewer hoặc editor
  final String sharedBy;
  final String createdAt;

  TaskShare({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.permission,
    required this.sharedBy,
    required this.createdAt,
  });

  factory TaskShare.fromJson(Map<String, dynamic> json) {
    return TaskShare(
      id: json['_id'] ?? json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      userId: json['userId'] ?? '',
      permission: json['permission'] ?? 'viewer',
      sharedBy: json['sharedBy'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'userId': userId,
      'permission': permission,
      'sharedBy': sharedBy,
    };
  }
}