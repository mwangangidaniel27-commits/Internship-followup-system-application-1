import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_model.dart';

class StudentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get student profile by user ID
  Future<StudentModel?> getStudentByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('students')
          .select('''
            *,
            users!students_user_id_fkey(full_name),
            supervisor:users!students_supervisor_id_fkey(full_name)
          ''')
          .eq('user_id', userId)
          .single();

      // Flatten the response
      final flattenedData = {
        ...response,
        'full_name': response['users']?['full_name'],
        'supervisor_name': response['supervisor']?['full_name'],
      };

      return StudentModel.fromJson(flattenedData);
    } catch (e) {
      print('Error fetching student: $e');
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
      print('Error updating student: $e');
      return false;
    }
  }
}