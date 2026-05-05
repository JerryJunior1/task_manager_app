import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/notification_service.dart';
import '../../domain/entities/task.dart';
import '../blocs/task/task_bloc.dart';
import 'add_edit_task_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _filter = 'All';
  Timer? _reminderTimer;
  final Set<String> _notifiedTaskIds = {};
  final Set<String> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();
    context.read<TaskBloc>().add(LoadTasks());
    NotificationService().requestPermissions();

    // In-app notifications for Web/Desktop when app is open
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkUpcomingTasks();
    });
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _checkUpcomingTasks() {
    final state = context.read<TaskBloc>().state;
    if (state is TaskLoaded) {
      final now = DateTime.now();
      for (var task in state.tasks) {
        if (!task.isDone && task.dueDate != null) {
          final difference = task.dueDate!.difference(now).inMinutes;
          // If task is due in 10 minutes or less (and not in the past)
          if (difference >= 0 && difference <= 10 && !_notifiedTaskIds.contains(task.id)) {
            _notifiedTaskIds.add(task.id);
            _showInAppNotification(task);
          }
        }
      }
    }
  }

  void _showInAppNotification(Task task) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rappel !', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${task.title} est prévue dans 10 min.', style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF5D46D1),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 80, left: 24, right: 24), // Float above bottom bar
      ),
    );
  }

  void _deleteSelectedTasks() {
    for (String id in _selectedTaskIds) {
      context.read<TaskBloc>().add(DeleteTaskEvent(id));
    }
    setState(() {
      _selectedTaskIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String?;
    final firstName = fullName != null && fullName.isNotEmpty ? fullName.split(' ')[0] : 'User';
    final isSelectionMode = _selectedTaskIds.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: const Color(0xFF5D46D1),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _selectedTaskIds.clear()),
              ),
              title: Text(
                '${_selectedTaskIds.length} sélectionnés',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Supprimer', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          content: Text('Voulez-vous vraiment supprimer ces ${_selectedTaskIds.length} tâches ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () {
                                _deleteSelectedTasks();
                                Navigator.pop(context);
                              },
                              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'TaskFlow',
                style: GoogleFonts.inter(
                  color: const Color(0xFF5D46D1),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Color(0xFF5D46D1)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Aucune nouvelle alerte', style: GoogleFonts.inter()),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.black87,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Hello, $firstName!',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state is TaskLoaded
                      ? 'You have ${state.tasks.where((t) => !t.isDone).length} tasks to focus on today'
                      : 'Loading your tasks...',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _FilterChip(
                      label: 'All', 
                      isSelected: _filter == 'All',
                      onTap: () => setState(() => _filter = 'All'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending', 
                      isSelected: _filter == 'Pending',
                      onTap: () => setState(() => _filter = 'Pending'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Done', 
                      isSelected: _filter == 'Done',
                      onTap: () => setState(() => _filter = 'Done'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: state is TaskLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state is TaskLoaded
                          ? Builder(
                              builder: (context) {
                                final filteredTasks = state.tasks.where((t) {
                                  if (_filter == 'Pending') return !t.isDone;
                                  if (_filter == 'Done') return t.isDone;
                                  return true;
                                }).toList();

                                if (filteredTasks.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No $_filter tasks',
                                      style: GoogleFonts.inter(color: Colors.grey),
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  itemCount: filteredTasks.length,
                                  itemBuilder: (context, index) {
                                    final task = filteredTasks[index];
                                    final isSelected = _selectedTaskIds.contains(task.id);
                                    return TaskCard(
                                      task: task,
                                      isSelected: isSelected,
                                      isSelectionMode: isSelectionMode,
                                      onToggleSelection: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedTaskIds.remove(task.id);
                                          } else {
                                            _selectedTaskIds.add(task.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                );
                              },
                            )
                          : const SizedBox(),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditTaskScreen()),
          );
        },
        backgroundColor: const Color(0xFF5D46D1),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        selectedItemColor: const Color(0xFF5D46D1),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.task_outlined), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5D46D1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onToggleSelection;

  const TaskCard({
    super.key, 
    required this.task,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onToggleSelection,
      onTap: () {
        if (isSelectionMode) {
          onToggleSelection();
        } else {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: Colors.white,
              title: Text(task.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    Text('Description', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(task.description!, style: GoogleFonts.inter(color: Colors.grey[700])),
                    const SizedBox(height: 16),
                  ],
                  if (task.dueDate != null) ...[
                    Text('Due Date', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(DateFormat('MMM d, yyyy - h:mm a').format(task.dueDate!), style: GoogleFonts.inter(color: Colors.grey[700])),
                    const SizedBox(height: 16),
                  ],
                  Text('Status', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(task.isDone ? 'Completed' : 'Pending', style: GoogleFonts.inter(color: task.isDone ? Colors.green : Colors.orange)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.inter(color: const Color(0xFF5D46D1))),
                ),
              ],
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5D46D1).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: const Color(0xFF5D46D1), width: 2) : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isSelectionMode)
              Container(
                margin: const EdgeInsets.only(right: 16),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFF5D46D1) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF5D46D1) : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              )
            else
              GestureDetector(
                onTap: () {
                  context.read<TaskBloc>().add(UpdateTaskEvent(task.copyWith(isDone: !task.isDone)));
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isDone ? const Color(0xFF4CAF50) : Colors.transparent,
                    border: Border.all(
                      color: task.isDone ? const Color(0xFF4CAF50) : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: task.isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                      color: task.isDone ? Colors.grey : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (task.dueDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Due ${DateFormat('MMM d, h:mm a').format(task.dueDate!)}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!isSelectionMode)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddEditTaskScreen(task: task)),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
