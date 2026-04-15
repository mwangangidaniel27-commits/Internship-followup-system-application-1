class WeeklyLogModel {
  final String id;
  final String studentId;
  final int weekNumber;
  final DateTime logDate;
  final String description;
  final String status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String companyVerificationStatus;
  final String? companyVerifiedBy;
  final DateTime? companyVerifiedAt;

  // From joined feedback table
  final String? feedback;
  final String? supervisorName;

  WeeklyLogModel({
    required this.id,
    required this.studentId,
    required this.weekNumber,
    required this.logDate,
    required this.description,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.companyVerificationStatus = 'pending',
    this.companyVerifiedBy,
    this.companyVerifiedAt,
    this.feedback,
    this.supervisorName,
  });

  factory WeeklyLogModel.fromJson(Map<String, dynamic> json) {
    return WeeklyLogModel(
      id: json['id'],
      studentId: json['student_id'],
      weekNumber: json['week_number'],
      logDate: DateTime.parse(json['log_date']),
      description: json['description'],
      status: json['status'] ?? 'pending',
      submittedAt: DateTime.parse(json['submitted_at']),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      companyVerificationStatus: json['company_verification_status'] ?? 'pending',
      companyVerifiedBy: json['company_verified_by'],
      companyVerifiedAt: json['company_verified_at'] != null
          ? DateTime.parse(json['company_verified_at'])
          : null,
      feedback: json['feedback'],
      supervisorName: json['supervisor_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'week_number': weekNumber,
      'log_date': logDate.toIso8601String().split('T')[0],
      'description': description,
      'status': status,
    };
  }

  bool get isReviewed => status == 'reviewed';
  bool get isPending => status == 'pending';
  bool get isCompanyVerified => companyVerificationStatus == 'verified';
  bool get hasFeedback => feedback != null && feedback!.isNotEmpty;
}
