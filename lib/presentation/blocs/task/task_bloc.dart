import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/notification_service.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/repositories/task_repository.dart';

// Events
abstract class TaskEvent extends Equatable {
  const TaskEvent();
  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {}

class AddTaskEvent extends TaskEvent {
  final Task task;
  const AddTaskEvent(this.task);
  @override
  List<Object?> get props => [task];
}

class UpdateTaskEvent extends TaskEvent {
  final Task task;
  const UpdateTaskEvent(this.task);
  @override
  List<Object?> get props => [task];
}

class DeleteTaskEvent extends TaskEvent {
  final String taskId;
  const DeleteTaskEvent(this.taskId);
  @override
  List<Object?> get props => [taskId];
}

// States
abstract class TaskState extends Equatable {
  const TaskState();
  @override
  List<Object?> get props => [];
}

class TaskInitial extends TaskState {}
class TaskLoading extends TaskState {}
class TaskLoaded extends TaskState {
  final List<Task> tasks;
  const TaskLoaded(this.tasks);
  @override
  List<Object?> get props => [tasks];
}
class TaskError extends TaskState {
  final String message;
  const TaskError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository taskRepository;

  TaskBloc({required this.taskRepository}) : super(TaskLoading()) {
    on<LoadTasks>((event, emit) async {
      emit(TaskLoading());
      try {
        final tasks = await taskRepository.getTasks();
        // Re-schedule notifications in case they were cleared by the system
        for (var task in tasks) {
          NotificationService().scheduleTaskReminder(task);
        }
        emit(TaskLoaded(tasks));
      } catch (e) {
        emit(TaskError(e.toString()));
      }
    });

    on<AddTaskEvent>((event, emit) async {
      if (state is TaskLoaded) {
        final currentTasks = List<Task>.from((state as TaskLoaded).tasks);
        emit(TaskLoading());
        try {
          final newTask = await taskRepository.addTask(event.task);
          currentTasks.add(newTask);
          NotificationService().scheduleTaskReminder(newTask);
          emit(TaskLoaded(currentTasks));
        } catch (e) {
          emit(TaskError(e.toString()));
        }
      }
    });

    on<UpdateTaskEvent>((event, emit) async {
      if (state is TaskLoaded) {
        final currentTasks = List<Task>.from((state as TaskLoaded).tasks);
        emit(TaskLoading());
        try {
          final updatedTask = await taskRepository.updateTask(event.task);
          final index = currentTasks.indexWhere((t) => t.id == updatedTask.id);
          if (index != -1) {
            currentTasks[index] = updatedTask;
          }
          NotificationService().scheduleTaskReminder(updatedTask);
          emit(TaskLoaded(currentTasks));
        } catch (e) {
          emit(TaskError(e.toString()));
        }
      }
    });

    on<DeleteTaskEvent>((event, emit) async {
      if (state is TaskLoaded) {
        final currentTasks = List<Task>.from((state as TaskLoaded).tasks);
        emit(TaskLoading());
        try {
          await taskRepository.deleteTask(event.taskId);
          currentTasks.removeWhere((t) => t.id == event.taskId);
          NotificationService().cancelReminder(event.taskId);
          emit(TaskLoaded(currentTasks));
        } catch (e) {
          emit(TaskError(e.toString()));
        }
      }
    });
  }
}
