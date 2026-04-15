import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/week_log_model.dart';

class LogService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create a new log
  Future<bool> createLog(WeeklyLogModel log) async {
    try {
      await _supabase
          .from('weekly_logs')
          .insert(log.toJson());
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating log: $e');
      }
      return false;
    }
  }

  // Get all logs for a student
  Future<List<WeeklyLogModel>> getStudentLogs(String studentId) async {
    try {
      if (kDebugMode) print('Fetching logs for student_id: $studentId');

      final response = await _supabase
          .from('weekly_logs')
          .select('id, student_id, week_number, log_date, description, status, submitted_at, reviewed_at, created_at, updated_at, company_verification_status, company_verified_by, company_verified_at')
          .eq('student_id', studentId)
          .order('week_number', ascending: false);

      if (kDebugMode) print('Logs response count: ${(response as List).length}');

      List<WeeklyLogModel> logs = [];
      
      for (var log in response as List) {
        // Get feedback for this log separately
        final feedbackList = await _supabase
            .from('feedback')
            .select('comment, supervisor:users!feedback_supervisor_id_fkey(full_name)')
            .eq('log_id', log['id'])
            .order('created_at', ascending: false)
            .limit(1);
        final feedbackResponse = (feedbackList as List).isNotEmpty ? feedbackList.first : null;

        final flattenedLog = <String, dynamic>{
          ...Map<String, dynamic>.from(log),
          'feedback': feedbackResponse?['comment'],
          'supervisor_name': feedbackResponse?['supervisor']?['full_name'],
        };
        
        try {
          logs.add(WeeklyLogModel.fromJson(flattenedLog));
        } catch (parseError) {
          if (kDebugMode) print('Error parsing log: $parseError | data: $flattenedLog');
        }
      }

      if (kDebugMode) print('Successfully parsed ${logs.length} logs');
      return logs;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching logs: $e');
      }
      return [];
    }
  }

  // Get recent logs (last 3)
  Future<List<WeeklyLogModel>> getRecentLogs(String studentId) async {
    try {
      final response = await _supabase
          .from('weekly_logs')
          .select('id, student_id, week_number, log_date, description, status, submitted_at, reviewed_at, created_at, updated_at, company_verification_status, company_verified_by, company_verified_at')
          .eq('student_id', studentId)
          .order('week_number', ascending: false)
          .limit(3);

      List<WeeklyLogModel> logs = [];
      
      for (var log in response as List) {
        // Get feedback for this log separately
        final feedbackList = await _supabase
            .from('feedback')
            .select('comment')
            .eq('log_id', log['id'])
            .order('created_at', ascending: false)
            .limit(1);
        final feedbackResponse = (feedbackList as List).isNotEmpty ? feedbackList.first : null;

        final flattenedLog = <String, dynamic>{
          ...Map<String, dynamic>.from(log),
          'feedback': feedbackResponse?['comment'],
        };
        
        logs.add(WeeklyLogModel.fromJson(flattenedLog));
      }

      return logs;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching recent logs: $e');
      }
      return [];
    }
  }

  // Get log by ID
  Future<WeeklyLogModel?> getLogById(String logId) async {
    try {
      final response = await _supabase
          .from('weekly_logs')
          .select('id, student_id, week_number, log_date, description, status, submitted_at, reviewed_at, created_at, updated_at, company_verification_status, company_verified_by, company_verified_at')
          .eq('id', logId)
          .single();

      // Get feedback separately
      final feedbackList = await _supabase
          .from('feedback')
          .select('comment, supervisor:users!feedback_supervisor_id_fkey(full_name)')
          .eq('log_id', logId)
          .order('created_at', ascending: false)
          .limit(1);
      final feedbackResponse = (feedbackList as List).isNotEmpty ? feedbackList.first : null;

      final flattenedLog = <String, dynamic>{
        ...Map<String, dynamic>.from(response),
        'feedback': feedbackResponse?['comment'],
        'supervisor_name': feedbackResponse?['supervisor']?['full_name'],
      };

      return WeeklyLogModel.fromJson(flattenedLog);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching log: $e');
      }
      return null;
    }
  }

  // Check if log exists for week
  Future<bool> logExistsForWeek(String studentId, int weekNumber) async {
    try {
      final response = await _supabase
          .from('weekly_logs')
          .select('id')
          .eq('student_id', studentId)
          .eq('week_number', weekNumber)
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking log existence: $e');
      }
      return false;
    }
  }
}