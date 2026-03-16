import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _filterRole = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _supabase
          .from('users')
          .select('*')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(users);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredUsers {
    List<Map<String, dynamic>> list = _users;
    if (_filterRole != 'all') {
      list = list.where((u) => u['role'] == _filterRole).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) {
        final name = (u['full_name'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }
    return list;
  }

  // ─── ADD USER ────────────────────────────────────────────────────────────────

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final departmentCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final studentIdCtrl = TextEditingController();
    String selectedRole = 'student';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add New User'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Valid email required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: ['student', 'supervisor', 'admin']
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r[0].toUpperCase() + r.substring(1)),
                              ))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedRole = v!),
                    ),
                    const SizedBox(height: 12),
                    // Department — shown for student and supervisor
                    if (selectedRole == 'student' || selectedRole == 'supervisor')
                      TextFormField(
                        controller: departmentCtrl,
                        decoration: const InputDecoration(labelText: 'Department'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    // Student ID — only for students
                    if (selectedRole == 'student') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: studentIdCtrl,
                        decoration: const InputDecoration(labelText: 'Student ID'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ],
                    // Title — only for supervisors
                    if (selectedRole == 'supervisor') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Title (e.g. Senior Engineer)'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      await _createUser(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        password: passwordCtrl.text,
                        role: selectedRole,
                        department: departmentCtrl.text.trim(),
                        title: titleCtrl.text.trim(),
                        studentId: studentIdCtrl.text.trim(),
                        ctx: ctx,
                      );
                      setDialogState(() => isSubmitting = false);
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required BuildContext ctx,
    String department = '',
    String title = '',
    String studentId = '',
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-user',
        body: {
          'full_name': name,
          'email': email,
          'password': password,
          'role': role,
          if (department.isNotEmpty) 'department': department,
          if (title.isNotEmpty) 'title': title,
          if (studentId.isNotEmpty) 'student_id': studentId,
        },
      );

      final data = response.data as List;
      final result = data.first as Map<String, dynamic>;

      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Unknown error');
      }

      if (mounted) {
        Navigator.pop(ctx);
        _loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User "$name" created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── EDIT USER ───────────────────────────────────────────────────────────────

  void _showEditUserDialog(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user['full_name']);
    String selectedRole = user['role'] ?? 'student';
    bool isActive = user['is_active'] ?? true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit User'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['student', 'supervisor', 'admin']
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r[0].toUpperCase() + r.substring(1)),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _supabase.from('users').update({
                          'full_name': nameCtrl.text.trim(),
                          'role': selectedRole,
                          'is_active': isActive,
                        }).eq('id', user['id']);
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadUsers();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User updated successfully'),
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
                      setDialogState(() => isSubmitting = false);
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DEACTIVATE / DELETE ─────────────────────────────────────────────────────

  void _showUserOptions(Map<String, dynamic> user) {
    final isActive = user['is_active'] ?? true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit User'),
              onTap: () {
                Navigator.pop(context);
                _showEditUserDialog(user);
              },
            ),
            ListTile(
              leading: Icon(
                isActive ? Icons.block : Icons.check_circle_outline,
                color: isActive ? Colors.orange : Colors.green,
              ),
              title: Text(isActive ? 'Deactivate User' : 'Activate User'),
              onTap: () async {
                Navigator.pop(context);
                await _supabase
                    .from('users')
                    .update({'is_active': !isActive}).eq('id', user['id']);
                _loadUsers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          isActive ? 'User deactivated' : 'User activated'),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete User',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete "${user['full_name']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase
                    .from('users')
                    .delete()
                    .eq('id', user['id']);
                _loadUsers();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── BULK UPLOAD ─────────────────────────────────────────────────────────────

  void _showBulkUploadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Upload Users'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload a CSV file with the following columns:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Required: full_name, email, password, role\n\n'
                'Student extras (optional):\n'
                'student_id, department, company_name,\n'
                'company_address, internship_start_date,\n'
                'internship_end_date, total_weeks\n\n'
                'Supervisor extras (optional):\n'
                'department, title\n\n'
                'Roles: student | supervisor | admin\n'
                'Dates format: YYYY-MM-DD',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _downloadTemplate(),
              icon: const Icon(Icons.download),
              label: const Text('Download Template'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pickAndUploadCSV();
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose File'),
          ),
        ],
      ),
    );
  }

  void _downloadTemplate() {
    // Template content as CSV
    const csvContent =
        'full_name,email,password,role,student_id,department,company_name,'
        'company_address,internship_start_date,internship_end_date,total_weeks,title\n'
        'John Doe,john@example.com,password123,student,STU001,Computer Science,'
        'Tech Corp,Nairobi Kenya,2025-01-06,2025-04-06,12,\n'
        'Jane Smith,jane@example.com,password123,supervisor,,Engineering,,,,,,'
        'Senior Engineer\n';

    if (kDebugMode) {
      print('CSV Template:\n$csvContent');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Template: full_name, email, password, role — copy this format'),
      ),
    );
  }

  Future<void> _pickAndUploadCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final content = utf8.decode(bytes);
      final lines = content
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (lines.length < 2) {
        _showSnack('CSV file is empty or has no data rows', isError: true);
        return;
      }

      // Parse header
      final headers =
          lines[0].split(',').map((h) => h.trim().toLowerCase()).toList();
      final requiredCols = ['full_name', 'email', 'password', 'role'];
      for (final col in requiredCols) {
        if (!headers.contains(col)) {
          _showSnack('Missing column: $col', isError: true);
          return;
        }
      }

      final nameIdx = headers.indexOf('full_name');
      final emailIdx = headers.indexOf('email');
      final passIdx = headers.indexOf('password');
      final roleIdx = headers.indexOf('role');
      final studentIdIdx = headers.indexOf('student_id');
      final deptIdx = headers.indexOf('department');
      final companyNameIdx = headers.indexOf('company_name');
      final companyAddrIdx = headers.indexOf('company_address');
      final startDateIdx = headers.indexOf('internship_start_date');
      final endDateIdx = headers.indexOf('internship_end_date');
      final weeksIdx = headers.indexOf('total_weeks');
      final titleIdx = headers.indexOf('title');

      final dataRows = lines.sublist(1);
      int success = 0;
      final List<String> errors = [];

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Uploading ${dataRows.length} users...'),
              ],
            ),
          ),
        );
      }

      for (final line in dataRows) {
        final cols = line.split(',').map((c) => c.trim()).toList();
        if (cols.length < 4) {
          errors.add('Skipped malformed row: $line');
          continue;
        }

        final name = cols[nameIdx];
        final email = cols[emailIdx];
        final password = cols[passIdx];
        final role = cols[roleIdx].toLowerCase();

        if (!['student', 'supervisor', 'admin'].contains(role)) {
          errors.add('Invalid role "$role" for $email');
          continue;
        }

        try {
          String? getCol(int idx) =>
              idx >= 0 && idx < cols.length && cols[idx].isNotEmpty
                  ? cols[idx]
                  : null;

          final res = await _supabase.functions.invoke(
            'create-user',
            body: {
              'full_name': name,
              'email': email,
              'password': password,
              'role': role,
              if (getCol(studentIdIdx) != null) 'student_id': getCol(studentIdIdx),
              if (getCol(deptIdx) != null) 'department': getCol(deptIdx),
              if (getCol(companyNameIdx) != null) 'company_name': getCol(companyNameIdx),
              if (getCol(companyAddrIdx) != null) 'company_address': getCol(companyAddrIdx),
              if (getCol(startDateIdx) != null) 'internship_start_date': getCol(startDateIdx),
              if (getCol(endDateIdx) != null) 'internship_end_date': getCol(endDateIdx),
              if (getCol(weeksIdx) != null) 'total_weeks': getCol(weeksIdx),
              if (getCol(titleIdx) != null) 'title': getCol(titleIdx),
            },
          );
          final data = res.data as List;
          final result = data.first as Map<String, dynamic>;
          if (result['success'] == true) {
            success++;
          } else {
            errors.add('Failed for $email: ${result['error']}');
          }
        } catch (e) {
          errors.add('Failed for $email: $e');
        }
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      _loadUsers();
      _showBulkResultDialog(success, errors);
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack('Error: $e', isError: true);
      }
    }
  }

  void _showBulkResultDialog(int success, List<String> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Complete'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('$success users created successfully'),
                ],
              ),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Text('${errors.length} errors:'),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      errors.join('\n'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: const Color(0xFF2563EB),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Upload CSV',
            onPressed: _showBulkUploadDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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

          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Students', 'student'),
                const SizedBox(width: 8),
                _buildFilterChip('Supervisors', 'supervisor'),
                const SizedBox(width: 8),
                _buildFilterChip('Admins', 'admin'),
              ],
            ),
          ),

          // User Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${filteredUsers.length} user${filteredUsers.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No users found',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            return _buildUserCard(user);
                          },
                        ),
                      ),
          ),
        ],
      ),

      // FAB — Add single user
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterRole = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFF2563EB) : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    Color roleColor;
    switch (user['role']) {
      case 'student':
        roleColor = const Color(0xFF2563EB);
        break;
      case 'supervisor':
        roleColor = const Color(0xFF8B5CF6);
        break;
      case 'admin':
        roleColor = const Color(0xFFEF4444);
        break;
      default:
        roleColor = Colors.grey;
    }

    final isActive = user['is_active'] ?? true;
    final name = user['full_name'] ?? '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: roleColor.withOpacity(isActive ? 0.15 : 0.06),
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  color: isActive ? roleColor : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isActive)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF111827) : Colors.grey,
                ),
              ),
            ),
            if (!isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'INACTIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['email'] ?? '',
              style: TextStyle(
                  color: isActive
                      ? const Color(0xFF6B7280)
                      : Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (user['role'] ?? 'unknown').toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: roleColor,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showUserOptions(user),
        ),
        isThreeLine: true,
      ),
    );
  }
}