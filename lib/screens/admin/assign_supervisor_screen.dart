import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AssignSupervisorScreen extends StatefulWidget {
  const AssignSupervisorScreen({super.key});

  @override
  State<AssignSupervisorScreen> createState() => _AssignSupervisorScreenState();
}

class _AssignSupervisorScreenState extends State<AssignSupervisorScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _supervisors = [];
  List<Map<String, dynamic>> _assignments = [];

  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load students (with their current supervisor assignment if any)
      final students = await _supabase
          .from('users')
          .select('id, full_name, email')
          .eq('role', 'student')
          .eq('is_active', true)
          .order('full_name');

      // Load supervisors
      final supervisors = await _supabase
          .from('users')
          .select('id, full_name, email')
          .eq('role', 'supervisor')
          .eq('is_active', true)
          .order('full_name');

      // Load existing assignments
      final assignments = await _supabase
          .from('supervisor_assignments')
          .select('id, student_id, supervisor_id, assigned_at');

      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(students);
          _supervisors = List<Map<String, dynamic>>.from(supervisors);
          _assignments = List<Map<String, dynamic>>.from(assignments);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Get supervisor assigned to a student (if any)
  Map<String, dynamic>? _getAssignedSupervisor(String studentId) {
    final assignment = _assignments.where(
      (a) => a['student_id'] == studentId,
    ).toList();
    if (assignment.isEmpty) return null;
    final supId = assignment.first['supervisor_id'];
    try {
      return _supervisors.firstWhere((s) => s['id'] == supId);
    } catch (_) {
      return null;
    }
  }

  // Get students assigned to a supervisor
  List<Map<String, dynamic>> _getAssignedStudents(String supervisorId) {
    final assignedIds = _assignments
        .where((a) => a['supervisor_id'] == supervisorId)
        .map((a) => a['student_id'])
        .toSet();
    return _students.where((s) => assignedIds.contains(s['id'])).toList();
  }

  // Assign or reassign supervisor to student
  Future<void> _assignSupervisor(
      String studentId, String supervisorId) async {
    try {
      // Check if assignment exists
      final existing = _assignments
          .where((a) => a['student_id'] == studentId)
          .toList();

      if (existing.isNotEmpty) {
        // Update existing
        await _supabase
            .from('supervisor_assignments')
            .update({
              'supervisor_id': supervisorId,
              'assigned_at': DateTime.now().toIso8601String(),
            })
            .eq('student_id', studentId);
      } else {
        // Insert new
        await _supabase.from('supervisor_assignments').insert({
          'student_id': studentId,
          'supervisor_id': supervisorId,
          'assigned_at': DateTime.now().toIso8601String(),
        });
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supervisor assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Remove assignment
  Future<void> _removeAssignment(String studentId) async {
    try {
      await _supabase
          .from('supervisor_assignments')
          .delete()
          .eq('student_id', studentId);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAssignDialog(Map<String, dynamic> student) {
    final currentSupervisor = _getAssignedSupervisor(student['id']);
    String? selectedSupervisorId = currentSupervisor?['id'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Assign Supervisor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['full_name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            student['email'],
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Supervisor',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_supervisors.isEmpty)
                const Text('No supervisors available.',
                    style: TextStyle(color: Colors.grey))
              else
                DropdownButtonFormField<String>(
                  value: selectedSupervisorId,
                  hint: const Text('Choose a supervisor'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  items: _supervisors
                      .map((s) => DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text(s['full_name']),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedSupervisorId = v),
                ),
            ],
          ),
          actions: [
            if (currentSupervisor != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _removeAssignment(student['id']);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedSupervisorId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _assignSupervisor(
                          student['id'], selectedSupervisorId!);
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FILTERED LISTS ───────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    final q = _searchQuery.toLowerCase();
    return _students.where((s) {
      return (s['full_name'] ?? '').toLowerCase().contains(q) ||
          (s['email'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSupervisors {
    if (_searchQuery.isEmpty) return _supervisors;
    final q = _searchQuery.toLowerCase();
    return _supervisors.where((s) {
      return (s['full_name'] ?? '').toLowerCase().contains(q) ||
          (s['email'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Assign Supervisors'),
        backgroundColor: const Color(0xFF2563EB),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school, size: 18),
                  const SizedBox(width: 6),
                  Text('By Student (${_students.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, size: 18),
                  const SizedBox(width: 6),
                  Text('By Supervisor (${_supervisors.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),

                // Stats bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      _buildStatPill(
                        '${_assignments.length} Assigned',
                        const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      _buildStatPill(
                        '${_students.length - _assignments.length} Unassigned',
                        const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                ),

                // Tab views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStudentTab(),
                      _buildSupervisorTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // Tab 1: Students view — each student shows their assigned supervisor
  Widget _buildStudentTab() {
    final students = _filteredStudents;
    if (students.isEmpty) {
      return const Center(child: Text('No students found'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          final supervisor = _getAssignedSupervisor(student['id']);
          final isAssigned = supervisor != null;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  (student['full_name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                student['full_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['email'] ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  isAssigned
                      ? Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 13, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              supervisor['full_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 13, color: Colors.orange[700]),
                            const SizedBox(width: 4),
                            Text(
                              'No supervisor assigned',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: () => _showAssignDialog(student),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAssigned
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isAssigned ? 'Change' : 'Assign',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  // Tab 2: Supervisors view — each supervisor shows their student count
  Widget _buildSupervisorTab() {
    final supervisors = _filteredSupervisors;
    if (supervisors.isEmpty) {
      return const Center(child: Text('No supervisors found'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: supervisors.length,
        itemBuilder: (context, index) {
          final supervisor = supervisors[index];
          final assignedStudents = _getAssignedStudents(supervisor['id']);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFF5F3FF),
                child: Text(
                  (supervisor['full_name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                supervisor['full_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(supervisor['email'] ?? ''),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: assignedStudents.isEmpty
                      ? Colors.grey.withOpacity(0.1)
                      : const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${assignedStudents.length} student${assignedStudents.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: assignedStudents.isEmpty
                        ? Colors.grey
                        : const Color(0xFF8B5CF6),
                  ),
                ),
              ),
              children: assignedStudents.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No students assigned yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    ]
                  : assignedStudents
                      .map(
                        (student) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 0),
                          leading: const Icon(Icons.school,
                              size: 18, color: Color(0xFF2563EB)),
                          title: Text(
                            student['full_name'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            student['email'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.link_off,
                                size: 18, color: Colors.red),
                            tooltip: 'Remove assignment',
                            onPressed: () =>
                                _confirmRemove(student, supervisor),
                          ),
                        ),
                      )
                      .toList(),
            ),
          );
        },
      ),
    );
  }

  void _confirmRemove(
      Map<String, dynamic> student, Map<String, dynamic> supervisor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: Text(
          'Remove "${student['full_name']}" from "${supervisor['full_name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeAssignment(student['id']);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}