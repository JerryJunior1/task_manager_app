class Task {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isDone;
  final String userId;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.isDone = false,
    required this.userId,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isDone,
    String? userId,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isDone: isDone ?? this.isDone,
      userId: userId ?? this.userId,
    );
  }
}
