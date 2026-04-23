import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';

class SupabaseTaskRepository implements TaskRepository {
  final SupabaseClient _supabase;

  SupabaseTaskRepository(this._supabase);

  @override
  Future<List<Task>> getTasks() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    final response = await _supabase
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .order('created_at');

    return (response as List<dynamic>).map((json) => _taskFromJson(json)).toList();
  }

  @override
  Future<Task> addTask(Task task) async {
    final response = await _supabase.from('tasks').insert({
      'title': task.title,
      'description': task.description,
      'due_date': task.dueDate?.toIso8601String(),
      'is_done': task.isDone,
      'user_id': task.userId,
    }).select().single();

    return _taskFromJson(response);
  }

  @override
  Future<Task> updateTask(Task task) async {
    final response = await _supabase.from('tasks').update({
      'title': task.title,
      'description': task.description,
      'due_date': task.dueDate?.toIso8601String(),
      'is_done': task.isDone,
    }).eq('id', task.id).select().single();

    return _taskFromJson(response);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _supabase.from('tasks').delete().eq('id', taskId);
  }

  Task _taskFromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      isDone: json['is_done'] as bool? ?? false,
      userId: json['user_id'].toString(),
    );
  }
}
