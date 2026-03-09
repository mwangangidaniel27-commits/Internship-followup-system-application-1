import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/student_model.dart';

class StudentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get student profile by user ID
  Future<StudentModel?> getStudentByUserId(String userId) async {
    try {
      // First get student record
      final studentResponse = await _supabase
          .from('students')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (studentResponse == null) {
        if (kDebugMode) {
          print('No student profile found for user: $userId');
        }
        return null;
      }

      // Get user full name
      final userResponse = await _supabase
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      // Get supervisor name if supervisor_id exists
      String? supervisorName;
      if (studentResponse['supervisor_id'] != null) {
        final supervisorResponse = await _supabase
            .from('users')
            .select('full_name')
            .eq('id', studentResponse['supervisor_id'])
            .maybeSingle();
        supervisorName = supervisorResponse?['full_name'];
      }

      // Flatten the response
      final flattenedData = <String, dynamic>{
        ...Map<String, dynamic>.from(studentResponse),
        'full_name': userResponse?['full_name'],
        'supervisor_name': supervisorName,
      };

      return StudentModel.fromJson(flattenedData);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching student: $e');
      }
      return null;
    }
  }

  // Update student profile
  Future<bool> updateStudent(String studentId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('students')
          .update(updates)
          .eq('id', studentId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating student: $e');
      }
      return false;
    }
  }
}