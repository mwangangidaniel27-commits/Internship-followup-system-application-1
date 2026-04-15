import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  final String supervisorType;

  const StudentDetailScreen({
    super.key,
    required this.student,
    this.supervisorType = 'university',
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _evaluations = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadEvaluations();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final logs = await _supabase
          .from('weekly_logs')
          .select('*, feedback(*)')
          .eq('student_id', widget.student['id'])
          .order('week_number', ascending: false);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(logs);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading logs: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addFeedback(Map<String, dynamic> log) async {
    final controller = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Feedback for Week ${log['week_number']}'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter your feedback...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    final companyStatus = log['company_verification_status'] ?? 'pending';
    if (widget.supervisorType == 'university' && companyStatus != 'verified') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This log must be verified by the company supervisor first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        // Add feedback
        await _supabase.from('feedback').insert({
          'log_id': log['id'],
          'supervisor_id': _supabase.auth.currentUser!.id,
          'comment': controller.text.trim(),
        });

        // Update log status
        await _supabase
            .from('weekly_logs')
            .update({
              'status': 'reviewed',
              'reviewed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', log['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Feedback submitted successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _loadLogs();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error submitting feedback: $e');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit feedback'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }



  Future<void> _verifyCompanyLog(Map<String, dynamic> log) async {
    try {
      await _supabase.from('weekly_logs').update({
        'company_verification_status': 'verified',
        'company_verified_by': _supabase.auth.currentUser!.id,
        'company_verified_at': DateTime.now().toIso8601String(),
      }).eq('id', log['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log verified and forwarded to university supervisor'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }

      _loadLogs();
    } catch (e) {
      if (kDebugMode) print('Error verifying log: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to verify log'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadEvaluations() async {
    try {
      final evals = await _supabase
          .from('evaluations')
          .select('*')
          .eq('student_id', widget.student['id'])
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _evaluations = List<Map<String, dynamic>>.from(evals);
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading evaluations: $e');
    }
  }

  Future<void> _uploadEvaluation() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() => _isUploading = true);

      final fileName =
          '${widget.student["id"]}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = 'evaluations/$fileName';

      // Upload to Supabase Storage
      await _supabase.storage.from('internship-documents').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );

      // Get public URL
      final fileUrl =
          _supabase.storage.from('internship-documents').getPublicUrl(filePath);

      // Save record to evaluations table
      await _supabase.from('evaluations').insert({
        'student_id': widget.student['id'],
        'supervisor_id': _supabase.auth.currentUser!.id,
        'file_url': fileUrl,
        'file_name': file.name,
        'notes': null,
      });

      await _loadEvaluations();

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evaluation uploaded successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Upload error: \$e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddNoteDialog(Map<String, dynamic> eval) {
    final noteCtrl = TextEditingController(text: eval['notes'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter notes for this evaluation...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabase
                  .from('evaluations')
                  .update({'notes': noteCtrl.text.trim()})
                  .eq('id', eval['id']);
              _loadEvaluations();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = widget.student['users'];
    final fullName = userData?['full_name'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(fullName),
        backgroundColor: const Color(0xFF2563EB),
        actions: [
          _isUploading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.upload_file),
                  tooltip: 'Upload Evaluation',
                  onPressed: _uploadEvaluation,
                ),
        ],
      ),
      body: Column(
        children: [
          // Student Info Card
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('ID: ${widget.student['student_id']}'),
                Text('Company: ${widget.student['company_name'] ?? 'Not assigned'}'),
                Text('Department: ${widget.student['department']}'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Evaluations Section
          if (_evaluations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Evaluations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_evaluations.length} uploaded',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _evaluations.length,
                itemBuilder: (context, index) {
                  final eval = _evaluations[index];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.picture_as_pdf,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                eval['file_name'] ?? 'Evaluation',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          eval['notes'] ?? 'No notes',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showAddNoteDialog(eval),
                              child: const Text('Add note',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF2563EB))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Logs Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Weekly Logs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_logs.length} logs',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(child: Text('No logs submitted yet'))
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final feedback = log['feedback'] as List?;
                            final hasFeedback = feedback != null && feedback.isNotEmpty;
                            final companyStatus = log['company_verification_status'] ?? 'pending';
                            final isCompanySupervisor = widget.supervisorType == 'company';
                            final canUniversityReview = companyStatus == 'verified';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ExpansionTile(
                                leading: Container(
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
                                title: Text(
                                  'Week ${log['week_number']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  DateFormat('MMM d, yyyy').format(DateTime.parse(log['log_date'])),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: log['status'] == 'reviewed'
                                        ? const Color(0xFFD1FAE5)
                                        : companyStatus == 'verified'
                                            ? const Color(0xFFE0E7FF)
                                            : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    log['status'] == 'reviewed'
                                        ? 'Reviewed'
                                        : companyStatus == 'verified'
                                            ? 'Company Verified'
                                            : 'Pending',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: log['status'] == 'reviewed'
                                          ? const Color(0xFF059669)
                                          : companyStatus == 'verified'
                                              ? const Color(0xFF4338CA)
                                              : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Description:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          log['description'],
                                          style: const TextStyle(height: 1.5),
                                        ),
                                        
                                        if (hasFeedback) ...[
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCE7FE),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(Icons.chat_bubble, size: 16, color: Color(0xFF2563EB)),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Your Feedback',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF1E40AF),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  feedback.first['comment'],
                                                  style: const TextStyle(color: Color(0xFF1E40AF)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        const SizedBox(height: 16),
                                        if (isCompanySupervisor && companyStatus != 'verified')
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _verifyCompanyLog(log),
                                              icon: const Icon(Icons.verified),
                                              label: const Text('Verify Log Submission'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                              ),
                                            ),
                                          )
                                        else if (isCompanySupervisor && companyStatus == 'verified')
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 14),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              color: const Color(0xFFD1FAE5),
                                            ),
                                            child: const Text(
                                              'Already verified by company supervisor',
                                              style: TextStyle(
                                                color: Color(0xFF065F46),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          )
                                        else ...[
                                          if (!canUniversityReview)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 12, horizontal: 14),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                color: const Color(0xFFFFEDD5),
                                              ),
                                              child: const Text(
                                                'Waiting for company supervisor verification',
                                                style: TextStyle(
                                                  color: Color(0xFF9A3412),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            )
                                          else
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () => _addFeedback(log),
                                                icon: const Icon(Icons.add_comment),
                                                label: Text(hasFeedback
                                                    ? 'Update Feedback'
                                                    : 'Add Feedback'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF2563EB),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}