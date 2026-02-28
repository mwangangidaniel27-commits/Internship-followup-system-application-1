class StudentModel {
  final String id;
  final String userId;
  final String studentId;
  final String department;
  final String? companyName;
  final String? companyAddress;
  final DateTime? internshipStartDate;
  final DateTime? internshipEndDate;
  final int totalWeeks;
  final String? supervisorId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional fields from joined queries
  final String? fullName;
  final String? supervisorName;

  StudentModel({
    required this.id,
    required this.userId,
    required this.studentId,
    required this.department,
    this.companyName,
    this.companyAddress,
    this.internshipStartDate,
    this.internshipEndDate,
    required this.totalWeeks,
    this.supervisorId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.fullName,
    this.supervisorName,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      userId: json['user_id'],
      studentId: json['student_id'],
      department: json['department'],
      companyName: json['company_name'],
      companyAddress: json['company_address'],
      internshipStartDate: json['internship_start_date'] != null
          ? DateTime.parse(json['internship_start_date'])
          : null,
      internshipEndDate: json['internship_end_date'] != null
          ? DateTime.parse(json['internship_end_date'])
          : null,
      totalWeeks: json['total_weeks'] ?? 12,
      supervisorId: json['supervisor_id'],
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      fullName: json['full_name'],
      supervisorName: json['supervisor_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'student_id': studentId,
      'department': department,
      'company_name': companyName,
      'company_address': companyAddress,
      'internship_start_date': internshipStartDate?.toIso8601String(),
      'internship_end_date': internshipEndDate?.toIso8601String(),
      'total_weeks': totalWeeks,
      'supervisor_id': supervisorId,
      'status': status,
    };
  }

  int get currentWeek {
    if (internshipStartDate == null) return 0;
    final now = DateTime.now();
    final difference = now.difference(internshipStartDate!).inDays;
    return (difference / 7).floor() + 1;
  }
}