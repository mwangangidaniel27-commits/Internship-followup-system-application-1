import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  User? _user;
  String? _userRole;
  String _supervisorType = 'university';
  bool _isLoading = false;
  String? _errorMessage;
  bool _isActive = true;
  String _approvalStatus = 'approved';

  User? get user => _user;
  String? get userRole => _userRole;
  String get supervisorType => _supervisorType;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isActive => _isActive;
  String get approvalStatus => _approvalStatus;

  AuthProvider() {
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _fetchUserRole();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    });
  }

  Future<void> _fetchUserRole() async {
    try {
      final response = await _supabase
          .from('users')
          .select('role, is_active, approval_status')
          .eq('id', _user!.id)
          .single();

      _userRole = response['role'];
      _isActive = response['is_active'] ?? true;
      _approvalStatus = response['approval_status'] ?? 'approved';

      if (_userRole == 'supervisor') {
        final supervisor = await _supabase
            .from('supervisors')
            .select('supervisor_type')
            .eq('user_id', _user!.id)
            .maybeSingle();
        _supervisorType = supervisor?['supervisor_type'] ?? 'university';
      } else {
        _supervisorType = 'university';
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user role: $e');
      }
      _errorMessage = 'Failed to fetch user role';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _user = response.user;

      if (_user != null) {
        await _fetchUserRole();

        if (!_isActive || _approvalStatus == 'pending') {
          await _supabase.auth.signOut();
          _user = null;
          _userRole = null;
          _errorMessage =
              'Your account is pending admin approval. Please try again later.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerUserPendingApproval({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String supervisorType = 'university',
    String department = '',
    String title = '',
    String studentId = '',
    String companyName = '',
    String companyAddress = '',
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _supabase.functions.invoke(
        'self-register-user',
        body: {
          'full_name': fullName,
          'email': email,
          'password': password,
          'role': role,
          if (department.isNotEmpty) 'department': department,
          if (title.isNotEmpty) 'title': title,
          if (studentId.isNotEmpty) 'student_id': studentId,
          if (companyName.isNotEmpty) 'company_name': companyName,
          if (companyAddress.isNotEmpty) 'company_address': companyAddress,
          if (role == 'supervisor') 'supervisor_type': supervisorType,
        },
      );

      final data = response.data as Map<String, dynamic>;

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Registration failed');
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _user = null;
      _userRole = null;
      _supervisorType = 'university';
      _isActive = true;
      _approvalStatus = 'approved';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> checkAuth() async {
    final session = _supabase.auth.currentSession;
    _user = session?.user;
    if (_user != null) {
      await _fetchUserRole();
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
