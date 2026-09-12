import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'supabase_service.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  final _client = SupabaseService.client;

  User? get currentAuthUser => _client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      debugPrint('=== SIGNIN START ===');
      debugPrint('Email: $normalizedEmail');

      final existingUser = await _client
          .from('users')
          .select('id')
          .ilike('email', normalizedEmail)
          .maybeSingle();

      debugPrint(
        'User lookup result: ${existingUser != null ? "Found" : "Not found"}',
      );

      if (existingUser == null) {
        throw const AuthFailure('Account not found. Please sign up first');
      }

      debugPrint('Attempting Supabase auth sign in...');

      final response = await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      if (response.user == null) {
        throw const AuthFailure(
          'Invalid credentials. Please check email and password.',
        );
      }

      debugPrint('Sign in successful! User ID: ${response.user?.id}');
      debugPrint('=== SIGNIN SUCCESS ===');
    } on AuthException catch (e, st) {
      debugPrint('AuthService.signIn AuthException: $e\n$st');
      throw AuthFailure(_mapSignInError(e));
    } on AuthFailure {
      rethrow;
    } catch (e, st) {
      debugPrint('AuthService.signIn error: $e\n$st');
      throw AuthFailure(_mapGenericError(e));
    }
  }

  Future<void> signUp({
    required String name,
    required String phone,
    required String vehicleNumber,
    required String aadharNumber,
    required String email,
    required String password,
    required String batteryType,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      debugPrint('=== SIGNUP START ===');
      debugPrint('Email: $normalizedEmail');

      final response = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
      );
      final user = response.user;

      debugPrint(
        'Auth signup response - User ID: ${user?.id}, Email confirmed: ${user?.emailConfirmedAt}',
      );

      if (user == null) {
        throw const AuthFailure('Signup failed. Please try again.');
      }

      debugPrint('Auth user created successfully!');
      debugPrint('Updating user profile with additional fields...');

      // Update the auto-created user with profile data
      await _client
          .from('users')
          .update({
            'name': name,
            'phone': phone,
            'vehicle_number': vehicleNumber,
            'aadhar_number': aadharNumber,
            'battery_type': batteryType,
          })
          .eq('id', user.id);

      debugPrint('User profile updated successfully!');
      debugPrint('=== SIGNUP SUCCESS ===');
    } on AuthException catch (e, st) {
      debugPrint('AuthService.signUp AuthException: $e\n$st');
      throw AuthFailure(_mapSignUpError(e));
    } on PostgrestException catch (e, st) {
      debugPrint('AuthService.signUp PostgrestException: $e\n$st');
      debugPrint('Error Code: ${e.code}');
      debugPrint('Error Message: ${e.message}');
      debugPrint('Error Details: ${e.toString()}');
      throw AuthFailure(_mapSignUpDataError(e));
    } on AuthFailure {
      rethrow;
    } catch (e, st) {
      debugPrint('AuthService.signUp error: $e\n$st');
      throw AuthFailure(_mapGenericError(e));
    }
  }

  Future<AppUser?> getProfile() async {
    try {
      final user = currentAuthUser;
      if (user == null) return null;
      final response = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (response == null) return null;
      return AppUser.fromMap(response);
    } catch (e, st) {
      debugPrint('AuthService.getProfile error: $e\n$st');
      return null;
    }
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String vehicleNumber,
    required String aadharNumber,
  }) async {
    try {
      final user = currentAuthUser;
      if (user == null) throw Exception('User not signed in');

      await _client
          .from('users')
          .update({
            'name': name,
            'phone': phone,
            'vehicle_number': vehicleNumber,
            'aadhar_number': aadharNumber,
          })
          .eq('id', user.id);
    } catch (e, st) {
      debugPrint('AuthService.updateProfile error: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateCurrentBattery({
    required int slotId,
    required String stationId,
  }) async {
    try {
      final user = currentAuthUser;
      if (user == null) throw Exception('User not signed in');

      debugPrint('Updating user battery: Slot $slotId at Station $stationId');

      await _client
          .from('users')
          .update({
            'assigned_battery_id': slotId,
            'battery_status': 'active',
            'current_battery_slot_id': slotId,
            'current_station_id': stationId,
          })
          .eq('id', user.id);

      debugPrint('User battery updated successfully');
    } catch (e, st) {
      debugPrint('AuthService.updateCurrentBattery error: $e\n$st');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e, st) {
      debugPrint('AuthService.signOut error: $e\n$st');
      rethrow;
    }
  }

  String _mapSignInError(AuthException error) {
    final message = error.message.toLowerCase();
    debugPrint('SignIn error message: $message');

    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return 'Wrong password. Please try again.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please check your email and confirm your account before logging in.';
    }
    if (message.contains('email not found') ||
        message.contains('user not found')) {
      return 'This account does not exist. Please sign up first.';
    }
    return _mapGenericError(error);
  }

  String _mapSignUpError(AuthException error) {
    final message = error.message.toLowerCase();
    debugPrint('SignUp error message: $message');

    if (message.contains('already registered') ||
        message.contains('already been registered') ||
        message.contains('user already registered')) {
      return 'An account with this email already exists. Please log in.';
    }
    if (message.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (message.contains('weak password')) {
      return 'Password must be at least 6 characters.';
    }
    return _mapGenericError(error);
  }

  String _mapSignUpDataError(PostgrestException error) {
    final message = error.message.toLowerCase();
    debugPrint(
      'SignUpDataError - Code: ${error.code}, Message: ${error.message}',
    );

    if (message.contains('duplicate') || message.contains('unique')) {
      return 'An account with this email already exists. Please log in.';
    }
    if (message.contains('permission')) {
      return 'Database permission error. Please contact support.';
    }
    if (message.contains('relation') && message.contains('does not exist')) {
      return 'Database table error. Please contact support.';
    }
    if (message.contains('check constraint')) {
      return 'Invalid data format. Please check all fields and try again.';
    }

    debugPrint('Raw error message: ${error.message}');
    return 'Failed to create account: ${error.message}';
  }

  String _mapGenericError(Object error) {
    final message = error.toString().toLowerCase();
    debugPrint('GenericError: $message');

    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('failed host lookup') ||
        message.contains('clientexception') ||
        message.contains('fetch')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    if (message.contains('permission denied')) {
      return 'Permission denied. Please contact support.';
    }
    if (message.contains('42p01') || message.contains('undefined table')) {
      return 'Database table missing. Please contact support.';
    }

    return 'Error: ${error.toString()}';
  }
}
