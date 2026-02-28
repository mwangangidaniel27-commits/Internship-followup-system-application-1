import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  User? _user;
  String? _userRole;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _fetchUserRole();
      }
      notifyListeners();
    });
  }

  // Fetch user role from database
  Future<void> _fetchUserRole() async {
    try {
      final response = await _supabase
          .from('users')
          .select('role')
          .eq('id', _user!.id)
          .single();
      
      _userRole = response['role'];
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }
  }

  // Sign in with email and password
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

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _user = null;
      _userRole = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Check if user is logged in
  Future<void> checkAuth() async {
    final session = _supabase.auth.currentSession;
    _user = session?.user;
    if (_user != null) {
      await _fetchUserRole();
    }
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}