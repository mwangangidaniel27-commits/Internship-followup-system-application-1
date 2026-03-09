import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/student_provider.dart';
import 'dart:io';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
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
      final docs = await _supabase
          .from('documents')
          .select('*')
          .eq('student_id', studentProvider.student!.id)
          .order('uploaded_at', ascending: false);

      if (mounted) {
        setState(() {
          _documents = List<Map<String, dynamic>>.from(docs);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading documents: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load documents';
        });
      }
    }
  }

  Future<void> _pickAndUploadDocument() async {
    final studentProvider = context.read<StudentProvider>();
    
    if (studentProvider.student == null) {
      _showError('Student profile not found');
      return;
    }

    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null) return;

      final file = result.files.first;
      
      // Check file size (max 10MB)
      if (file.size > 10 * 1024 * 1024) {
        _showError('File size must be less than 10MB');
        return;
      }

      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${studentProvider.student!.userId}/$timestamp-${file.name}';

      // Upload to Supabase Storage
      final bytes = kIsWeb ? file.bytes! : await File(file.path!).readAsBytes();
      
      await _supabase.storage
          .from('internship-documents')
          .uploadBinary(fileName, bytes);

      // Save metadata to database
      await _supabase.from('documents').insert({
        'student_id': studentProvider.student!.id,
        'document_type': 'final_report',
        'file_name': file.name,
        'file_path': fileName,
        'file_size': file.size,
        'uploaded_by': studentProvider.student!.userId,
      });

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        // Reload documents
        _loadDocuments();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading document: $e');
      }
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _showError('Failed to upload document. Please try again.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDocuments,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
              children: [
                // Upload Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _pickAndUploadDocument,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),

                // Info Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE7FE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2563EB)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Upload your final internship report (PDF only, max 10MB)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Documents List
                Expanded(
                  child: _documents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No documents uploaded yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadDocuments,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _documents.length,
                            itemBuilder: (context, index) {
                              final doc = _documents[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCE7FE),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.picture_as_pdf,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  title: Text(
                                    doc['file_name'],
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(_formatFileSize(doc['file_size'] ?? 0)),
                                      Text(
                                        'Uploaded ${DateFormat('MMM d, yyyy').format(DateTime.parse(doc['uploaded_at']))}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Uploaded',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ),
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