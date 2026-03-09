class AppRoutes {
  // Auth routes
  static const String splash = '/';
  static const String login = '/login';
  
  // Student routes
  static const String studentDashboard = '/student/dashboard';
  static const String studentProfile = '/student/profile';
  static const String profile = '/student/profile';
  static const String logForm = '/student/log_form';
  static const String logHistory = '/student/log_history';
  static const String logDetail = '/student/log_detail';
  static const String feedback = '/student/feedback';
  static const String documentUpload = '/student/document_upload';
  
  // Supervisor routes
  static const String supervisorDashboard = '/supervisor/dashboard';
  static const String studentList = '/supervisor/students';
  static const String studentDetail = '/supervisor/student_detail';
  static const String logReview = '/supervisor/log_review';
  static const String feedbackForm = '/supervisor/feedback';
  static const String evaluationUpload = '/supervisor/evaluation_upload';
  
  // Admin routes
  static const String adminDashboard = '/admin/dashboard';
  static const String userManagement = '/admin/users';
  static const String addUser = '/admin/add_user';
  static const String assignSupervisor = '/admin/assign_supervisor';
  static const String reports = '/admin/reports';
  
  // Reporting routes
  static const String assessmentStatus = '/reporting/assessment_status';
  static const String activeInternships = '/reporting/active_internships';
  static const String logCompliance = '/reporting/log_compliance';
}