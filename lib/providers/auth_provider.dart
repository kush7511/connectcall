import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

/// App-wide auth state, exposed via ChangeNotifier + Provider so
/// any screen can react to sign-in/sign-out without prop-drilling.
///
/// We chose plain Provider/ChangeNotifier (over Bloc or Riverpod)
/// because the app's state graph is shallow - auth state, one active
/// call, one contacts list - and ChangeNotifier keeps that simple
/// and easy to explain, while still cleanly separating business
/// logic (services) from UI (screens/widgets).
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _loading = true;
  String? _error;

  AuthProvider() {
    _authService.authStateChanges.listen((user) {
      _user = user;
      _loading = false;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoading => _loading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  Future<bool> login(String email, String password) async {
    _error = null;
    try {
      await _authService.login(email: email, password: password);
      return true;
    } catch (e) {
      _error = _authService.friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password, {
    String? phoneNumber,
  }) async {
    _error = null;
    try {
      await _authService.register(
        name: name,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
      );
      return true;
    } catch (e) {
      _error = _authService.friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() => _authService.logout();

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
