import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/student_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/log_service.dart';
import '../../models/week_log_model.dart';

class LogHistoryScreen extends StatefulWidget {
  const LogHistoryScreen({super.key});

  @override
  State<LogHistoryScreen> createState() => _LogHistoryScreenState();
}

class _LogHistoryScreenState extends State<LogHistoryScreen> {
  final LogService _logService = LogService();
  String _filterStatus = 'all'; // all, pending, reviewed
  List<WeeklyLogModel> _allLogs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final studentProvider = context.read<StudentProvider>();
    
    if (studentProvider.student == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Student profile not found';
      });
      return;
    }

    try {
      final logs = await _logService.getStudentLogs(studentProvider.student!.id);
      
      if (mounted) {
        setState(() {
          _allLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load logs';
        });
      }
    }
  }

  List<WeeklyLogModel> get filteredLogs {
    if (_filterStatus == 'all') return _allLogs;
    return _allLogs.where((log) => log.status == _filterStatus).toList();
  }

  int get pendingCount => _allLogs.where((log) => log.isPending).length;
  int get reviewedCount => _allLogs.where((log) => log.isReviewed).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          title: const Text('Weekly Logs'),
          backgroundColor: const Color(0xFF2563EB),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          title: const Text('Weekly Logs'),
          backgroundColor: const Color(0xFF2563EB),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadLogs,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2563EB),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Weekly Logs',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 80),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_allLogs.length} total entries',
                      style: const TextStyle(
                        color: Color(0xFFBFDBFE),
                        fontSize: 14,
                      ),
                    ),
                    FloatingActionButton.small(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.logForm).then((_) => _loadLogs());
                      },
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.add, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filter Tabs
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF2563EB),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      label: 'All (${_allLogs.length})',
                      value: 'all',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Pending ($pendingCount)',
                      value: 'pending',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Reviewed ($reviewedCount)',
                      value: 'reviewed',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stats Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.check_circle,
                      count: reviewedCount,
                      label: 'Reviewed',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.schedule,
                      count: pendingCount,
                      label: 'Pending',
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Logs List
          filteredLogs.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No logs found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start by creating your first weekly log',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final log = filteredLogs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildLogCard(log),
                        );
                      },
                      childCount: filteredLogs.length,
                    ),
                  ),
                ),

          // Bottom Spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required String value}) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF2563EB) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(WeeklyLogModel log) {
    final bool isReviewed = log.isReviewed;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to log detail
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE7FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Week ${log.weekNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, yyyy').format(log.logDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isReviewed 
                          ? const Color(0xFFD1FAE5) 
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isReviewed ? Icons.check_circle : Icons.schedule,
                          size: 14,
                          color: isReviewed 
                              ? const Color(0xFF059669) 
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isReviewed ? 'Reviewed' : 'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isReviewed 
                                ? const Color(0xFF059669) 
                                : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                log.description.length > 100 
                    ? '${log.description.substring(0, 100)}...' 
                    : log.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ),

            // Feedback Section
            if (isReviewed && log.hasFeedback)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE7FE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2563EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Supervisor Feedback',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.feedback!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                          if (log.reviewedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Reviewed on ${DateFormat('MMM d, yyyy').format(log.reviewedAt!)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Submitted ${DateFormat('MMM d, yyyy').format(log.submittedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                    ],
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