import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../providers/student_provider.dart';
import '../../providers/auth_provider.dart';

class StudentReportScreen extends StatefulWidget {
  const StudentReportScreen({super.key});

  @override
  State<StudentReportScreen> createState() => _StudentReportScreenState();
}

class _StudentReportScreenState extends State<StudentReportScreen> {
  final _supabase = Supabase.instance.client;
  bool _isGenerating = false;

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);

    try {
      final studentProvider = context.read<StudentProvider>();
      final authProvider = context.read<AuthProvider>();
      final student = studentProvider.student;

      if (student == null) throw Exception('Student profile not found');

      final dateFormat = DateFormat('MMM d, yyyy');

      // Fetch all logs
      final logsResponse = await _supabase
          .from('weekly_logs')
          .select('*')
          .eq('student_id', student.id)
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
        final fb =
            (feedbackList as List).isNotEmpty ? feedbackList.first : null;
        logsWithFeedback.add({
          ...Map<String, dynamic>.from(log),
          'feedback_comment': fb?['comment'],
          'feedback_supervisor': fb?['users']?['full_name'],
        });
      }

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
                    'Student Internship Report',
                    style: const pw.TextStyle(
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
            // Student Info
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
                    'Internship Report',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 12),
                  _pdfRow('Student Name', student.fullName ?? 'N/A'),
                  _pdfRow('Student ID', student.studentId),
                  _pdfRow('Email', authProvider.user?.email ?? 'N/A'),
                  _pdfRow('Department', student.department),
                  _pdfRow('Company', student.companyName ?? 'Not set'),
                  _pdfRow(
                      'Company Address', student.companyAddress ?? 'Not set'),
                  _pdfRow('Supervisor',
                      student.supervisorName ?? 'Not assigned'),
                  _pdfRow(
                    'Start Date',
                    student.internshipStartDate != null
                        ? dateFormat.format(student.internshipStartDate!)
                        : 'Not set',
                  ),
                  _pdfRow(
                    'End Date',
                    student.internshipEndDate != null
                        ? dateFormat.format(student.internshipEndDate!)
                        : 'Not set',
                  ),
                  _pdfRow('Total Weeks', '${student.totalWeeks} weeks'),
                  _pdfRow('Status', student.status.toUpperCase()),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Weekly Logs
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
                          mainAxisAlignment:
                              pw.MainAxisAlignment.spaceBetween,
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
                                borderRadius:
                                    pw.BorderRadius.circular(12),
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
                              crossAxisAlignment:
                                  pw.CrossAxisAlignment.start,
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

            pw.SizedBox(height: 30),

            // Signature Section
            pw.Text(
              'Signatures',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 16),
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
                    pw.SizedBox(height: 2),
                    pw.Text('Date: _______________',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey600)),
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
                    pw.SizedBox(height: 2),
                    pw.Text('Date: _______________',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      if (mounted) {
        setState(() => _isGenerating = false);
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'Internship_Report_${student.studentId}.pdf',
        );
      }
    } catch (e) {
      if (kDebugMode) print('PDF error: $e');
      if (mounted) {
        setState(() => _isGenerating = false);
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
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().student;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('My Report'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF2563EB).withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF)),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _StepItem(
                      number: '1',
                      text: 'Download your report PDF below'),
                  _StepItem(
                      number: '2',
                      text:
                          'Print it and get your company supervisor to sign'),
                  _StepItem(
                      number: '3',
                      text:
                          'Scan and upload the signed copy via Documents'),
                  _StepItem(
                      number: '4',
                      text:
                          'Your university supervisor will review and upload their evaluation'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Student summary card
            if (student != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Report Summary',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _infoRow('Student', student.fullName ?? 'N/A'),
                      _infoRow('ID', student.studentId),
                      _infoRow('Company',
                          student.companyName ?? 'Not set'),
                      _infoRow('Supervisor',
                          student.supervisorName ?? 'Not assigned'),
                      _infoRow('Status', student.status.toUpperCase()),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Download button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateReport,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  _isGenerating
                      ? 'Generating...'
                      : 'Download My Report (PDF)',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Upload signed doc button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/student/document_upload'),
                icon: const Icon(Icons.upload_file,
                    color: Color(0xFF2563EB)),
                label: const Text(
                  'Upload Signed Report',
                  style: TextStyle(
                      fontSize: 16, color: Color(0xFF2563EB)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF111827))),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String text;

  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1E40AF)),
            ),
          ),
        ],
      ),
    );
  }
}