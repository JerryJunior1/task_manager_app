import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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
  Timer? _reminderTimer;
  final Set<String> _notifiedTaskIds = {};

  @override
  void initState() {
    super.initState();
    context.read<TaskBloc>().add(LoadTasks());
    NotificationService().requestPermissions();

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
                  Text('Reminder', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${task.title} is due soon.', style: GoogleFonts.urbanist(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF246BFD),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 80, left: 24, right: 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF246BFD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_box_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Tasks',
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF212121),
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF212121), size: 28),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF212121), size: 28),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditTaskScreen()),
          );
        },
        backgroundColor: const Color(0xFF246BFD),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(0, Icons.home_filled, Icons.home_outlined),
                _buildNavItem(1, Icons.calendar_today, Icons.calendar_today_outlined),
                _buildNavItem(2, Icons.insert_chart, Icons.insert_chart_outlined),
                _buildNavItem(3, Icons.person, Icons.person_outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 1) return _buildPlaceholder('Calendar Screen');
    if (_selectedIndex == 2) return _buildPlaceholder('Analytics Screen');
    if (_selectedIndex == 3) return const ProfileScreen(); // Optional embedded Profile

    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        if (state is TaskLoading) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF246BFD)));
        }

        if (state is TaskLoaded) {
          final tasks = state.tasks;
          final recentProjects = tasks.take(3).toList();
          final todayTasks = tasks.toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 16.0, bottom: 80.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Recent Project', 'See All'),
                const SizedBox(height: 16),
                if (recentProjects.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: recentProjects.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _RecentProjectCard(
                            task: recentProjects[index],
                            gradientColors: index % 2 == 0 
                                ? [const Color(0xFFA678F1), const Color(0xFFECA3E2)]
                                : [const Color(0xFF558AF2), const Color(0xFF6EC6FF)],
                          ),
                        );
                      },
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'No recent projects.',
                      style: GoogleFonts.urbanist(color: Colors.grey.shade500),
                    ),
                  ),
                const SizedBox(height: 32),
                _buildSectionHeader('Today Task', 'See All'),
                const SizedBox(height: 16),
                if (todayTasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Center(
                      child: Text(
                        'You have no tasks today!',
                        style: GoogleFonts.urbanist(color: Colors.grey.shade500, fontSize: 16),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: todayTasks.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _TodayTaskTile(task: todayTasks[index]),
                      );
                    },
                  ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.urbanist(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF212121),
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Text(
              action,
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF246BFD),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String text) {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.urbanist(fontSize: 18, color: Colors.grey.shade500),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFF246BFD) : Colors.grey.shade400;
    final icon = isSelected ? selectedIcon : unselectedIcon;

    return GestureDetector(
      onTap: () {
        if (index == 3) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF246BFD),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentProjectCard extends StatelessWidget {
  final Task task;
  final List<Color> gradientColors;

  const _RecentProjectCard({required this.task, required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  task.isDone ? 'Completed' : 'In Progress',
                  style: GoogleFonts.urbanist(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(Icons.more_horiz, color: Colors.white),
            ],
          ),
          const Spacer(),
          Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            task.description ?? 'No description provided.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.urbanist(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 80,
            height: 24,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: _buildAvatar('A', Colors.yellow.shade700),
                ),
                Positioned(
                  left: 16,
                  child: _buildAvatar('B', Colors.red.shade400),
                ),
                Positioned(
                  left: 32,
                  child: _buildAvatar('C', Colors.blue.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial, Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

class _TodayTaskTile extends StatelessWidget {
  final Task task;

  const _TodayTaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditTaskScreen(task: task)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                context.read<TaskBloc>().add(UpdateTaskEvent(task.copyWith(isDone: !task.isDone)));
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: task.isDone ? const Color(0xFF246BFD) : Colors.transparent,
                  border: Border.all(
                    color: task.isDone ? const Color(0xFF246BFD) : const Color(0xFF246BFD),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: task.isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF212121),
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        task.dueDate != null 
                            ? 'Today • ${DateFormat('h:mm a').format(task.dueDate!)}'
                            : 'Anytime',
                        style: GoogleFonts.urbanist(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF9E9E9E)),
              onPressed: () {
                // Future options menu
              },
            ),
          ],
        ),
      ),
    );
  }
}
