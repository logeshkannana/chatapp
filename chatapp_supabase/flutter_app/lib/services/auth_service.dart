import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/models.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => supabase.auth.currentUser != null;
  String? get currentUserId => supabase.auth.currentUser?.id;

  AuthService() {
    // Listen to auth state changes
    supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        await _loadCurrentUser(session.user.id);
        await _setOnline(true);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });

    // Load user if already logged in
    if (isLoggedIn) {
      _loadCurrentUser(currentUserId!);
    }
  }

  Future<void> _loadCurrentUser(String uid) async {
    try {
      final data = await supabase
          .from('users')
          .select()
          .eq('id', uid)
          .single();
      _currentUser = UserModel.fromMap(data);
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  // ─── Sign Up ────────────────────────────────────────────────────────────────
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Create auth user
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _error = 'Signup failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Insert user profile into users table
      await supabase.from('users').insert({
        'id': response.user!.id,
        'name': name,
        'email': email,
        'phone': phone,
        'status': 'Hey there! I am using ChatApp',
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
        'profile_image_url': '',
      });

      _currentUser = UserModel(
        id: response.user!.id,
        name: name,
        email: email,
        phone: phone,
        isOnline: true,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Sign In ────────────────────────────────────────────────────────────────
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Sign Out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _setOnline(false);
    await supabase.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // ─── Password Reset ─────────────────────────────────────────────────────────
  Future<bool> sendPasswordReset(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Update Online Status ───────────────────────────────────────────────────
  Future<void> _setOnline(bool isOnline) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await supabase.from('users').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', uid);
    } catch (_) {}
  }
}
