import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  // Weekly Summary data
  List<Map<String, dynamic>> _weeklySummary = [];
  bool _loadingSummary = true;

  // Assessment Status data
  List<Map<String, dynamic>> _assessmentStatus = [];
  bool _loadingAssessment = true;

  // Students for report generation
  List<Map<String, dynamic>> _students = [];
  bool _loadingStudents = true;

  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWeeklySummary();
    _loadAssessmentStatus();
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── WEEKLY SUMMARY ──────────────────────────────────────────────────────────

  Future<void> _loadWeeklySummary() async {
    setState(() => _loadingSummary = true);
    try {
      final students = await _supabase
          .from('students')
          .select('id, student_id, department, status, users!students_user_id_fkey(full_name)')
          .order('created_at');

      final List<Map<String, dynamic>> summary = [];

      for (final s in students as List) {
        final logs = await _supabase
            .from('weekly_logs')
            .select('id, week_number, status')
            .eq('student_id', s['id']);

        final logList = logs as List;
        final total = logList.length;
        final reviewed = logList.where((l) => l['status'] == 'reviewed').length;
        final pending = logList.where((l) => l['status'] == 'pending').length;

        summary.add({
          'student_id': s['id'],
          'student_number': s['student_id'],
          'full_name': s['users']?['full_name'] ?? 'Unknown',
          'department': s['department'],
          'status': s['status'],
          'total_logs': total,
          'reviewed_logs': reviewed,
          'pending_logs': pending,
        });
      }

      if (mounted) {
        setState(() {
          _weeklySummary = summary;
          _loadingSummary = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading weekly summary: $e');
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  // ─── ASSESSMENT STATUS ────────────────────────────────────────────────────────

  Future<void> _loadAssessmentStatus() async {
    setState(() => _loadingAssessment = true);
    try {
      final students = await _supabase
          .from('students')
          .select('id, student_id, department, users!students_user_id_fkey(full_name)')
          .order('created_at');

      final List<Map<String, dynamic>> assessment = [];

      for (final s in students as List) {
        final evals = await _supabase
            .from('evaluations')
            .select('id, created_at, file_name')
            .eq('student_id', s['id'])
            .order('created_at', ascending: false)
            .limit(1);

        final evalList = evals as List;
        final hasEval = evalList.isNotEmpty;

        assessment.add({
          'student_id': s['id'],
          'student_number': s['student_id'],
          'full_name': s['users']?['full_name'] ?? 'Unknown',
          'department': s['department'],
          'has_evaluation': hasEval,
          'evaluation_date': hasEval ? evalList.first['created_at'] : null,
          'file_name': hasEval ? evalList.first['file_name'] : null,
        });
      }

      if (mounted) {
        setState(() {
          _assessmentStatus = assessment;
          _loadingAssessment = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading assessment status: $e');
      if (mounted) setState(() => _loadingAssessment = false);
    }
  }

  // ─── STUDENTS FOR REPORT ─────────────────────────────────────────────────────

  Future<void> _loadStudents() async {
    setState(() => _loadingStudents = true);
    try {
      final students = await _supabase
          .from('students')
          .select(
              'id, user_id, student_id, department, company_name, company_address, '
              'internship_start_date, internship_end_date, total_weeks, status, '
              'users!students_user_id_fkey(full_name, email)')
          .order('created_at');

      if (mounted) {
        setState(() {
          _students = List<Map<String, dynamic>>.from(students);
          _loadingStudents = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading students: $e');
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  // ─── PDF GENERATION ───────────────────────────────────────────────────────────

  Future<void> _generateStudentReport(Map<String, dynamic> student) async {
    setState(() => _generatingPdf = true);

    try {
      final studentId = student['id'];
      final fullName = student['users']?['full_name'] ?? 'Unknown';
      final email = student['users']?['email'] ?? '';
      final dateFormat = DateFormat('MMM d, yyyy');

      // Fetch logs
      final logsResponse = await _supabase
          .from('weekly_logs')
          .select('*')
          .eq('student_id', studentId)
          .order('week_number');

      final logs = logsResponse as List;

      // Fetch feedback for each log
      final List<Map<String, dynamic>> logsWithFeedback = [];
      for (final log in logs) {
        final feedbackList = await _supabase
            .from('feedback')
            .select('comment, users!feedback_supervisor_id_fkey(full_name)')
            .eq('log_id', log['id'])
            .limit(1);
        final fb = (feedbackList as List).isNotEmpty ? feedbackList.first : null;
        logsWithFeedback.add({
          ...Map<String, dynamic>.from(log),
          'feedback_comment': fb?['comment'],
          'feedback_supervisor': fb?['users']?['full_name'],
        });
      }

      // Fetch evaluation
      final evalResponse = await _supabase
          .from('evaluations')
          .select('file_name, notes, created_at')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(1);

      final eval = (evalResponse as List).isNotEmpty ? evalResponse.first : null;

      // Fetch supervisor
      final assignmentResponse = await _supabase
          .from('supervisor_assignments')
          .select('supervisor_id, users!supervisor_assignments_supervisor_id_fkey(full_name)')
          .eq('student_id', student['user_id'])
          .maybeSingle();

      final supervisorName =
          assignmentResponse?['users']?['full_name'] ?? 'Not assigned';

      // Build PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'University of Eastern Africa Baraton',
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800),
                  ),
                  pw.Text(
                    'Internship Report',
                    style: pw.TextStyle(
                        fontSize: 12, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Divider(color: PdfColors.blue800, thickness: 2),
              pw.SizedBox(height: 4),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${dateFormat.format(DateTime.now())}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey500),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey500),
              ),
            ],
          ),
          build: (context) => [
            // Student Info Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Student Internship Report',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 12),
                  _pdfRow('Student Name', fullName),
                  _pdfRow('Student ID', student['student_id'] ?? 'N/A'),
                  _pdfRow('Email', email),
                  _pdfRow('Department', student['department'] ?? 'N/A'),
                  _pdfRow('Company', student['company_name'] ?? 'Not set'),
                  _pdfRow('Company Address', student['company_address'] ?? 'Not set'),
                  _pdfRow('Supervisor', supervisorName),
                  _pdfRow(
                    'Start Date',
                    student['internship_start_date'] != null
                        ? dateFormat.format(DateTime.parse(student['internship_start_date']))
                        : 'Not set',
                  ),
                  _pdfRow(
                    'End Date',
                    student['internship_end_date'] != null
                        ? dateFormat.format(DateTime.parse(student['internship_end_date']))
                        : 'Not set',
                  ),
                  _pdfRow('Total Weeks', '${student['total_weeks'] ?? 0} weeks'),
                  _pdfRow('Status', (student['status'] ?? 'active').toUpperCase()),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Weekly Logs Section
            pw.Text(
              'Weekly Logs (${logsWithFeedback.length} entries)',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),

            if (logsWithFeedback.isEmpty)
              pw.Text('No logs submitted yet.',
                  style: const pw.TextStyle(color: PdfColors.grey600))
            else
              ...logsWithFeedback.map((log) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Week ${log['week_number']}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 13),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: pw.BoxDecoration(
                                color: log['status'] == 'reviewed'
                                    ? PdfColors.green100
                                    : PdfColors.orange100,
                                borderRadius: pw.BorderRadius.circular(12),
                              ),
                              child: pw.Text(
                                log['status'] == 'reviewed'
                                    ? 'Reviewed'
                                    : 'Pending',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: log['status'] == 'reviewed'
                                      ? PdfColors.green800
                                      : PdfColors.orange800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Date: ${dateFormat.format(DateTime.parse(log['log_date']))}',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey600),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          log['description'] ?? '',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        if (log['feedback_comment'] != null) ...[
                          pw.SizedBox(height: 8),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue50,
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Supervisor Feedback${log['feedback_supervisor'] != null ? ' (${log['feedback_supervisor']})' : ''}:',
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.blue800),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  log['feedback_comment'],
                                  style: const pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColors.blue900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )),

            pw.SizedBox(height: 20),

            // Evaluation Section
            pw.Text(
              'Evaluation',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            eval != null
                ? pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfRow('Evaluation File', eval['file_name'] ?? 'N/A'),
                        _pdfRow(
                          'Upload Date',
                          dateFormat.format(DateTime.parse(eval['created_at'])),
                        ),
                        if (eval['notes'] != null)
                          _pdfRow('Notes', eval['notes']),
                      ],
                    ),
                  )
                : pw.Text(
                    'No evaluation uploaded yet.',
                    style: const pw.TextStyle(color: PdfColors.grey600),
                  ),

            pw.SizedBox(height: 30),

            // Signature Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                        width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Company Supervisor Signature',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                        width: 150, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('University Supervisor Signature',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      if (mounted) {
        setState(() => _generatingPdf = false);
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'Internship_Report_${student['student_id']}.pdf',
        );
      }
    } catch (e) {
      if (kDebugMode) print('PDF error: $e');
      if (mounted) {
        setState(() => _generatingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: const Color(0xFF2563EB),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Weekly Summary'),
            Tab(text: 'Assessment'),
            Tab(text: 'Generate'),
          ],
        ),
      ),
      body: _generatingPdf
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF report...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklySummaryTab(),
                _buildAssessmentTab(),
                _buildGenerateTab(),
              ],
            ),
    );
  }

  // ─── TAB 1: WEEKLY SUMMARY ────────────────────────────────────────────────────

  Widget _buildWeeklySummaryTab() {
    if (_loadingSummary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_weeklySummary.isEmpty) {
      return const Center(child: Text('No student data found'));
    }

    final totalLogs = _weeklySummary.fold<int>(0, (sum, s) => sum + (s['total_logs'] as int));
    final totalReviewed = _weeklySummary.fold<int>(0, (sum, s) => sum + (s['reviewed_logs'] as int));
    final totalPending = _weeklySummary.fold<int>(0, (sum, s) => sum + (s['pending_logs'] as int));

    return RefreshIndicator(
      onRefresh: _loadWeeklySummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Overview stats
          Row(
            children: [
              Expanded(child: _statCard('Total Logs', totalLogs.toString(), const Color(0xFF2563EB), Icons.list_alt)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Reviewed', totalReviewed.toString(), const Color(0xFF10B981), Icons.check_circle)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Pending', totalPending.toString(), const Color(0xFFF59E0B), Icons.schedule)),
            ],
          ),

          const SizedBox(height: 20),

          const Text('Per Student Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ..._weeklySummary.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              (s['full_name'] as String)[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s['full_name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  '${s['student_number']} • ${s['department']}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: s['status'] == 'active'
                                  ? const Color(0xFFD1FAE5)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (s['status'] as String).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: s['status'] == 'active'
                                    ? const Color(0xFF059669)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _logPill('${s['total_logs']} Total',
                              const Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          _logPill('${s['reviewed_logs']} Reviewed',
                              const Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          _logPill('${s['pending_logs']} Pending',
                              const Color(0xFFF59E0B)),
                        ],
                      ),
                      if (s['total_logs'] > 0) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: s['reviewed_logs'] / s['total_logs'],
                            backgroundColor: const Color(0xFFE5E7EB),
                            color: const Color(0xFF10B981),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${((s['reviewed_logs'] / s['total_logs']) * 100).toStringAsFixed(0)}% reviewed',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ─── TAB 2: ASSESSMENT STATUS ─────────────────────────────────────────────────

  Widget _buildAssessmentTab() {
    if (_loadingAssessment) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_assessmentStatus.isEmpty) {
      return const Center(child: Text('No student data found'));
    }

    final assessed = _assessmentStatus.where((s) => s['has_evaluation'] == true).length;
    final notAssessed = _assessmentStatus.length - assessed;

    return RefreshIndicator(
      onRefresh: _loadAssessmentStatus,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                  child: _statCard('Assessed', assessed.toString(),
                      const Color(0xFF10B981), Icons.check_circle)),
              const SizedBox(width: 12),
              Expanded(
                  child: _statCard('Not Assessed', notAssessed.toString(),
                      const Color(0xFFEF4444), Icons.pending_actions)),
            ],
          ),

          const SizedBox(height: 20),

          const Text('Assessment Status per Student',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ..._assessmentStatus.map((s) {
            final hasEval = s['has_evaluation'] as bool;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      hasEval ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  child: Icon(
                    hasEval ? Icons.check : Icons.close,
                    color: hasEval
                        ? const Color(0xFF059669)
                        : const Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                title: Text(s['full_name'],
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['student_number']} • ${s['department']}',
                        style: const TextStyle(fontSize: 12)),
                    if (hasEval && s['evaluation_date'] != null)
                      Text(
                        'Evaluated: ${DateFormat('MMM d, yyyy').format(DateTime.parse(s['evaluation_date']))}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF10B981)),
                      )
                    else
                      const Text(
                        'No evaluation uploaded',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFFEF4444)),
                      ),
                  ],
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasEval
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasEval ? 'ASSESSED' : 'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasEval
                          ? const Color(0xFF059669)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
                isThreeLine: true,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── TAB 3: GENERATE REPORT ───────────────────────────────────────────────────

  Widget _buildGenerateTab() {
    if (_loadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return const Center(child: Text('No students found'));
    }

    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap "Generate" to create a full PDF report for a student including all logs, feedback and evaluation.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          ..._students.map((student) {
            final fullName = student['users']?['full_name'] ?? 'Unknown';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    fullName[0].toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${student['student_id']} • ${student['department'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: () => _generateStudentReport(student),
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────────

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _logPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}