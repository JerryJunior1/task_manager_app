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
                  Text('Rappel !', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${task.title} est prévue dans 10 min.', style: GoogleFonts.urbanist(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF246BFD),
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
      backgroundColor: Colors.white,
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: const Color(0xFF246BFD),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _selectedTaskIds.clear()),
              ),
              title: Text(
                '${_selectedTaskIds.length} sélectionnés',
                style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: Text('Supprimer', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, color: const Color(0xFF212121))),
                          content: Text('Voulez-vous vraiment supprimer ces ${_selectedTaskIds.length} tâches ?', style: GoogleFonts.urbanist(color: const Color(0xFF212121))),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Annuler', style: GoogleFonts.urbanist(color: const Color(0xFF9E9E9E), fontWeight: FontWeight.bold)),
                            ),
                            TextButton(
                              onPressed: () {
                                _deleteSelectedTasks();
                                Navigator.pop(context);
                              },
                              child: Text('Supprimer', style: GoogleFonts.urbanist(color: const Color(0xFFF75555), fontWeight: FontWeight.bold)),
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
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aura Tasks',
                    style: GoogleFonts.urbanist(
                      color: const Color(0xFF212121),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    DateFormat('EEEE, MMM d').format(DateTime.now()),
                    style: GoogleFonts.urbanist(
                      color: const Color(0xFF9E9E9E),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Color(0xFF246BFD)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
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
                  'Daily Progress',
                  style: GoogleFonts.urbanist(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 16),
                if (state is TaskLoaded)
                  _DailyProgressCard(tasks: state.tasks)
                else
                  const Center(child: CircularProgressIndicator(color: Color(0xFF246BFD))),
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
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF246BFD)))
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
                                      style: GoogleFonts.urbanist(color: const Color(0xFF9E9E9E), fontSize: 16),
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
        backgroundColor: const Color(0xFF246BFD),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
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
        selectedItemColor: const Color(0xFF246BFD),
        unselectedItemColor: const Color(0xFF9E9E9E),
        backgroundColor: Colors.white,
        elevation: 8,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
          color: isSelected ? const Color(0xFF246BFD) : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isSelected ? const Color(0xFF246BFD) : const Color(0xFFEEEEEE)),
        ),
        child: Text(
          label,
          style: GoogleFonts.urbanist(
            color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(task.title, style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 24, color: const Color(0xFF212121))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description != null && task.description!.isNotEmpty) ...[
                    Text('Description', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF9E9E9E))),
                    const SizedBox(height: 4),
                    Text(task.description!, style: GoogleFonts.urbanist(color: const Color(0xFF212121), fontSize: 16)),
                    const SizedBox(height: 16),
                  ],
                  if (task.dueDate != null) ...[
                    Text('Due Date', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF9E9E9E))),
                    const SizedBox(height: 4),
                    Text(DateFormat('MMM d, yyyy - h:mm a').format(task.dueDate!), style: GoogleFonts.urbanist(color: const Color(0xFF212121), fontSize: 16)),
                    const SizedBox(height: 16),
                  ],
                  Text('Status', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF9E9E9E))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: task.isDone ? const Color(0xFF4CAF50).withValues(alpha: 0.1) : const Color(0xFFFF9800).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.isDone ? 'Completed' : 'Pending', 
                      style: GoogleFonts.urbanist(
                        color: task.isDone ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddEditTaskScreen(task: task)),
                    );
                  },
                  child: Text('Edit', style: GoogleFonts.urbanist(color: const Color(0xFF9E9E9E), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.urbanist(color: const Color(0xFF246BFD), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: const Color(0xFF246BFD), width: 2) : Border.all(color: const Color(0xFFEEEEEE), width: 1),
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
                  color: isSelected ? const Color(0xFF246BFD) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF246BFD) : const Color(0xFFEEEEEE),
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
                    color: task.isDone ? const Color(0xFF246BFD) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: task.isDone ? const Color(0xFF246BFD) : const Color(0xFFEEEEEE),
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
                    style: GoogleFonts.urbanist(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                      color: task.isDone ? const Color(0xFF9E9E9E) : const Color(0xFF212121),
                    ),
                  ),
                  if (task.dueDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: const Color(0xFF9E9E9E)),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, HH:mm').format(task.dueDate!),
                            style: GoogleFonts.urbanist(
                              fontSize: 13,
                              color: const Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyProgressCard extends StatelessWidget {
  final List<Task> tasks;
  const _DailyProgressCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final todayTasks = tasks; 
    final total = todayTasks.length;
    final done = todayTasks.where((t) => t.isDone).length;
    final pending = total - done;
    final progress = total > 0 ? done / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF246BFD),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: Colors.white,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: GoogleFonts.urbanist(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatRow(icon: Icons.assignment_outlined, color: Colors.white, label: 'Total: $total'),
                const SizedBox(height: 12),
                _StatRow(icon: Icons.check_circle_outline, color: Colors.white, label: 'Done: $done'),
                const SizedBox(height: 12),
                _StatRow(icon: Icons.access_time, color: Colors.white, label: 'Pending: $pending'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StatRow({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.9)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.urbanist(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
