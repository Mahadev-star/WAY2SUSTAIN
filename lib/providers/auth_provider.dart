import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Initialize and listen for auth state changes
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize the auth service (loads stored user session)
      await _authService.initialize();

      // Get the current user from auth service
      _user = _authService.currentUser;
      notifyListeners();
    } catch (e) {
      _setError('Failed to initialize auth: $e');
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final newUser = await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      _user = newUser;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final loggedInUser = await _authService.loginWithEmail(
        email: email,
        password: password,
      );
      _user = loggedInUser;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      final googleUser = await _authService.signInWithGoogle();
      _user = googleUser;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithFacebook() async {
    _setLoading(true);
    _clearError();

    try {
      final facebookUser = await _authService.signInWithFacebook();
      _user = facebookUser;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loginAsGuest() async {
    _setLoading(true);
    _clearError();

    try {
      final guestUser = await _authService.loginAsGuest();
      _user = guestUser;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.resetPassword(email);
      // Show success message
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateEmail(String newEmail) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.updateEmail(newEmail);
      // Update local user if needed
      if (_user != null) {
        // Create updated user object
        final updatedUser = User(
          uid: _user!.uid,
          email: newEmail,
          displayName: _user!.displayName,
          photoURL: _user!.photoURL,
          isGuest: _user!.isGuest,
        );
        _user = updatedUser;
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.updatePassword(newPassword);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.updateUserProfile(data);

      // Update local user if needed
      if (_user != null && data.containsKey('displayName')) {
        final updatedUser = User(
          uid: _user!.uid,
          email: _user!.email,
          displayName: data['displayName'] as String?,
          photoURL: data['photoURL'] as String? ?? _user!.photoURL,
          isGuest: _user!.isGuest,
        );
        _user = updatedUser;
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAccount() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.deleteAccount();
      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Helper to get user data
  Future<Map<String, dynamic>?> getUserData() async {
    if (_user == null) return null;

    try {
      return await _authService.getUserData(_user!.uid);
    } catch (e) {
      _setError('Failed to get user data: $e');
      return null;
    }
  }

  // Check if user is a guest
  bool get isGuest => _user?.isGuest ?? false;

  // Get user display name
  String get displayName {
    if (_user == null) return 'Guest';
    return _user!.displayName ?? _user!.email?.split('@').first ?? 'Traveler';
  }

  // Get user email
  String? get userEmail => _user?.email;

  // Get user photo URL
  String? get photoURL => _user?.photoURL;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
