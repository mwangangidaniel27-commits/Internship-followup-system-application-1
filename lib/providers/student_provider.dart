import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../models/week_log_model.dart';
import '../services/student_service.dart';
import '../services/log_service.dart';

class StudentProvider with ChangeNotifier {
  final StudentService _studentService = StudentService();
  final LogService _logService = LogService();

  StudentModel? _student;
  List<WeeklyLogModel> _recentLogs = [];
  bool _isLoading = false;
  String? _errorMessage;

  StudentModel? get student => _student;
  List<WeeklyLogModel> get recentLogs => _recentLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load student data
  Future<void> loadStudentData(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _student = await _studentService.getStudentByUserId(userId);
      
      if (_student != null) {
        debugPrint('Loading recent logs for student id: ${_student!.id}');
        _recentLogs = await _logService.getRecentLogs(_student!.id);
        debugPrint('Recent logs loaded: ${_recentLogs.length}');
      } else {
        debugPrint('Student is null, skipping log load');
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load student data: $e';
      notifyListeners();
    }
  }

  // Refresh data
  Future<void> refreshData() async {
    if (_student != null) {
      await loadStudentData(_student!.userId);
    }
  }

  // Clear data
  void clearData() {
    _student = null;
    _recentLogs = [];
    _errorMessage = null;
    notifyListeners();
  }
}