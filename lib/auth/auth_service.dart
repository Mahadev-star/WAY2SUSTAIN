import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool isGuest;

  User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.isGuest = false,
  });
}

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Random _random = Random();

  User? _currentUser;

  // Get current user
  User? get currentUser => _currentUser;

  // Stream for auth state changes (simulated)
  Stream<User?> get authStateChanges => _createAuthStream();

  // Check if user exists in local storage
  Future<bool> _userExists(String userId) async {
    final userData = await _secureStorage.read(key: 'user_$userId');
    return userData != null;
  }

  // Create user profile in local storage
  Future<void> _createUserProfile(User user, {String? name}) async {
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'displayName': name ?? user.displayName ?? 'Traveler',
      'photoURL': user.photoURL,
      'createdAt': DateTime.now().toIso8601String(),
      'lastLogin': DateTime.now().toIso8601String(),
      'isGuest': false,
      'carbonSaved': 0.0,
      'tripsCompleted': 0,
      'ecoScore': 0,
      'preferences': {
        'transportMode': 'balanced',
        'notifications': true,
        'darkMode': true,
      },
    };

    await _secureStorage.write(
      key: 'user_${user.uid}',
      value: jsonEncode(userData),
    );

    // Store current user ID
    await _secureStorage.write(key: 'current_user_id', value: user.uid);
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _currentUser;
    if (user != null) {
      final userData = await _getUserData(user.uid);
      if (userData != null) {
        userData.addAll(data);
        userData['lastLogin'] = DateTime.now().toIso8601String();
        await _secureStorage.write(
          key: 'user_${user.uid}',
          value: jsonEncode(userData),
        );
      }
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    return await _getUserData(userId);
  }

  // ========== EMAIL/PASSWORD AUTH ==========

  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Check if user already exists (simulated)
      final existingUsers = await _getAllUsers();
      if (existingUsers.any((user) => user['email'] == email)) {
        throw 'An account already exists with this email.';
      }

      // Validate email
      if (!_isValidEmail(email)) {
        throw 'Invalid email address format.';
      }

      // Validate password
      if (password.length < 6) {
        throw 'Password should be at least 6 characters.';
      }

      // Create user with unique ID
      final userId = _generateUserId();
      final user = User(
        uid: userId,
        email: email,
        displayName: name,
      );

      // Save password (in real app, this should be hashed!)
      await _secureStorage.write(
        key: 'password_$userId',
        value: password,
      );

      // Create user profile
      await _createUserProfile(user, name: name);

      // Set as current user
      _currentUser = user;
      await _secureStorage.write(key: 'current_user_id', value: userId);

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Sign up error: $e');
      }
      throw e.toString();
    }
  }

  Future<User?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Find user by email
      final users = await _getAllUsers();
      final userData = users.firstWhere(
        (user) => user['email'] == email,
        orElse: () => throw 'No account found with this email.',
      );

      // Verify password (in real app, compare hashed passwords)
      final storedPassword = await _secureStorage.read(
        key: 'password_${userData['uid']}',
      );

      // Handle null storedPassword - this fixes the null safety error
      if (storedPassword == null || storedPassword != password) {
        throw 'Incorrect email or password.';
      }

      // Update last login
      userData['lastLogin'] = DateTime.now().toIso8601String();
      await _secureStorage.write(
        key: 'user_${userData['uid']}',
        value: jsonEncode(userData),
      );

      // Create user object - handle potential null values
      final user = User(
        uid: userData['uid'] as String? ?? '',
        email: userData['email'] as String?,
        displayName: userData['displayName'] as String?,
        photoURL: userData['photoURL'] as String?,
        isGuest: (userData['isGuest'] as bool?) ?? false,
      );

      // Set as current user
      _currentUser = user;
      await _secureStorage.write(
        key: 'current_user_id',
        value: userData['uid'],
      );

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      throw e.toString();
    }
  }

  // ========== SOCIAL AUTH ==========

  Future<User?> signInWithGoogle() async {
    try {
      // Simulate Google sign-in flow
      await Future.delayed(const Duration(seconds: 1));

      // Generate user data for Google sign-in
      final userId = _generateUserId();
      final user = User(
        uid: userId,
        email: 'google_user_${_random.nextInt(1000)}@example.com',
        displayName: 'Google User ${_random.nextInt(1000)}',
        photoURL: 'https://ui-avatars.com/api/?name=Google+User',
      );

      // Check if user exists, if not create profile
      if (!await _userExists(userId)) {
        await _createUserProfile(user);
      } else {
        await _updateLastLogin(userId);
      }

      // Set as current user
      _currentUser = user;
      await _secureStorage.write(key: 'current_user_id', value: userId);

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Google sign in error: $e');
      }
      throw 'Google sign in failed: $e';
    }
  }

  Future<User?> signInWithFacebook() async {
    try {
      // Simulate Facebook sign-in flow
      await Future.delayed(const Duration(seconds: 1));

      // Generate user data for Facebook sign-in
      final userId = _generateUserId();
      final user = User(
        uid: userId,
        email: 'facebook_user_${_random.nextInt(1000)}@example.com',
        displayName: 'Facebook User ${_random.nextInt(1000)}',
        photoURL: 'https://ui-avatars.com/api/?name=Facebook+User',
      );

      // Check if user exists, if not create profile
      if (!await _userExists(userId)) {
        await _createUserProfile(user);
      } else {
        await _updateLastLogin(userId);
      }

      // Set as current user
      _currentUser = user;
      await _secureStorage.write(key: 'current_user_id', value: userId);

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Facebook sign in error: $e');
      }
      throw 'Facebook sign in failed: $e';
    }
  }

  // ========== GUEST LOGIN ==========

  Future<User?> loginAsGuest() async {
    try {
      // Simulate guest login
      await Future.delayed(const Duration(milliseconds: 500));

      final userId = _generateUserId();
      final user = User(
        uid: userId,
        displayName: 'Eco Traveler',
        isGuest: true,
      );

      // Create guest profile
      final guestData = {
        'uid': userId,
        'isGuest': true,
        'createdAt': DateTime.now().toIso8601String(),
        'lastLogin': DateTime.now().toIso8601String(),
        'displayName': 'Eco Traveler',
        'carbonSaved': 0.0,
        'tripsCompleted': 0,
        'ecoScore': 0,
        'preferences': {
          'transportMode': 'balanced',
          'notifications': false,
          'darkMode': true,
        },
      };

      await _secureStorage.write(
        key: 'user_$userId',
        value: jsonEncode(guestData),
      );

      // Set as current user
      _currentUser = user;
      await _secureStorage.write(key: 'current_user_id', value: userId);

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Guest login error: $e');
      }
      throw 'Guest login failed: $e';
    }
  }

  // ========== PASSWORD RESET ==========

  Future<void> resetPassword(String email) async {
    try {
      // Simulate password reset email
      await Future.delayed(const Duration(seconds: 1));

      // Check if email exists
      final users = await _getAllUsers();
      final userExists = users.any((user) => user['email'] == email);

      if (!userExists) {
        throw 'No account found with this email.';
      }

      // In a real app, you would send an email here
      if (kDebugMode) {
        print('Password reset email would be sent to: $email');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Password reset error: $e');
      }
      throw e.toString();
    }
  }

  // ========== UPDATE PROFILE ==========

  Future<void> updateEmail(String newEmail) async {
    try {
      // Validate email
      if (!_isValidEmail(newEmail)) {
        throw 'Invalid email address format.';
      }

      // Check if email is already in use
      final users = await _getAllUsers();
      if (users.any((user) => user['email'] == newEmail)) {
        throw 'An account already exists with this email.';
      }

      final user = _currentUser;
      if (user != null) {
        final userData = await _getUserData(user.uid);
        if (userData != null) {
          userData['email'] = newEmail;
          await _secureStorage.write(
            key: 'user_${user.uid}',
            value: jsonEncode(userData),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Update email error: $e');
      }
      throw e.toString();
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      if (newPassword.length < 6) {
        throw 'Password should be at least 6 characters.';
      }

      final user = _currentUser;
      if (user != null) {
        await _secureStorage.write(
          key: 'password_${user.uid}',
          value: newPassword,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Update password error: $e');
      }
      throw e.toString();
    }
  }

  // ========== SIGN OUT ==========

  Future<void> signOut() async {
    try {
      _currentUser = null;
      await _secureStorage.delete(key: 'current_user_id');
    } catch (e) {
      if (kDebugMode) {
        print('Sign out error: $e');
      }
      rethrow;
    }
  }

  // ========== DELETE ACCOUNT ==========

  Future<void> deleteAccount() async {
    try {
      final user = _currentUser;
      if (user != null) {
        // Delete user data
        await _secureStorage.delete(key: 'user_${user.uid}');
        await _secureStorage.delete(key: 'password_${user.uid}');
        await _secureStorage.delete(key: 'current_user_id');

        _currentUser = null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Delete account error: $e');
      }
      throw 'Failed to delete account: $e';
    }
  }

  // ========== INITIALIZATION ==========

  Future<void> initialize() async {
    try {
      // Check for existing session
      final userId = await _secureStorage.read(key: 'current_user_id');
      if (userId != null) {
        final userData = await _getUserData(userId);
        if (userData != null) {
          _currentUser = User(
            uid: userData['uid'] as String? ?? '',
            email: userData['email'] as String?,
            displayName: userData['displayName'] as String?,
            photoURL: userData['photoURL'] as String?,
            isGuest: (userData['isGuest'] as bool?) ?? false,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Initialization error: $e');
      }
    }
  }

  // ========== HELPER METHODS ==========

  Future<void> _updateLastLogin(String userId) async {
    final userData = await _getUserData(userId);
    if (userData != null) {
      userData['lastLogin'] = DateTime.now().toIso8601String();
      await _secureStorage.write(
        key: 'user_$userId',
        value: jsonEncode(userData),
      );
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final data = await _secureStorage.read(key: 'user_$userId');
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getAllUsers() async {
    final allKeys = await _secureStorage.readAll();
    final users = <Map<String, dynamic>>[];

    for (final entry in allKeys.entries) {
      if (entry.key.startsWith('user_')) {
        final data = entry.value;
        final userData = jsonDecode(data) as Map<String, dynamic>;
        users.add(userData);
      }
    }

    return users;
  }

  String _generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  Stream<User?> _createAuthStream() async* {
    // Yield initial user state
    yield _currentUser;

    // In a real implementation, you might listen to storage changes
    // For now, we'll just return a stream that yields the current user
    final controller = StreamController<User?>();

    // Close the controller since we're not using it for real updates
    controller.close();

    yield* controller.stream;
  }
}
