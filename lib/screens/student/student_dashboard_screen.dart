import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentData();
    });
  }

  Future<void> _loadStudentData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      await studentProvider.loadStudentData(authProvider.user!.id);
    }
  }

  Future<void> _refreshData() async {
    await context.read<StudentProvider>().refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: _selectedIndex == 0
            ? _buildDashboard()
            : _buildPlaceholder(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDashboard() {
    return Consumer<StudentProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(provider.errorMessage!),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.student == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 64),
                const SizedBox(height: 16),
                const Text('No student profile'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        final student = provider.student!;
        final logs = provider.recentLogs;

        return RefreshIndicator(
          onRefresh: _refreshData,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${student.fullName?.split(' ')[0] ?? 'Student'}!',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                student.studentId,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFBFDBFE),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Progress Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Internship Details',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Week ${student.currentWeek}/${student.totalWeeks}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.business, size: 16, color: Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              const Text('Company: ', style: TextStyle(fontWeight: FontWeight.w500)),
                              Expanded(child: Text(student.companyName ?? 'Not assigned')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              const Text('Supervisor: ', style: TextStyle(fontWeight: FontWeight.w500)),
                              Expanded(child: Text(student.supervisorName ?? 'Not assigned')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.logForm),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Add Log'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.documentUpload),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Doc'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Logs
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.logHistory),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),

              // Logs List
              logs.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('No logs yet. Add your first log!'),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final log = logs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Card(
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCE7FE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.calendar_today, color: Color(0xFF2563EB), size: 20),
                                ),
                                title: Text('Week ${log.weekNumber}'),
                                subtitle: Text(DateFormat('MMM d, yyyy').format(log.logDate)),
                                trailing: log.hasFeedback
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Feedback',
                                          style: TextStyle(color: Colors.white, fontSize: 11),
                                        ),
                                      )
                                    : const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                              ),
                            ),
                          );
                        },
                        childCount: logs.length,
                      ),
                    ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    if (_selectedIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamed(context, AppRoutes.logHistory).then((_) {
          setState(() => _selectedIndex = 0);
        });
      });
    } else if (_selectedIndex == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamed(context, AppRoutes.feedback).then((_) {
          setState(() => _selectedIndex = 0);
        });
      });
    } else if (_selectedIndex == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamed(context, AppRoutes.profile).then((_) {
          setState(() => _selectedIndex = 0);
        });
      });
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) => setState(() => _selectedIndex = i),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2563EB),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Logs'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Feedback'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}