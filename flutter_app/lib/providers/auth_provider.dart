import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;
  String? _error;

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;
  bool get isAdmin => _user?['role'] == 'admin';
  bool get isSupervisor => _user?['role'] == 'supervisor';
  bool get isOfficer => _user?['role'] == 'officer';

  Future<void> checkAuth() async {
    try {
      final data = await ApiService.getMe();
      _user = data['user'];
      _status = AuthStatus.authenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      _error = null;
      final data = await ApiService.login(email, password);
      if (data['success']) {
        _user = data['user'];
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      _error = data['message'];
    } catch (e) {
      _error = 'Connection failed. Check your internet.';
    }
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
