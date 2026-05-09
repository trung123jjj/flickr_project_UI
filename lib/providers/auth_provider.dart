import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _currentUser;
  String? _authToken;
  String? _avatarUrl;
  bool _isLoading = false;

  String? get currentUser => _currentUser;
  String? get authToken => _authToken;
  String? get avatarUrl => _avatarUrl;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('current_user');
    _authToken = prefs.getString('auth_token');
    _avatarUrl = prefs.getString('user_avatar');
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await BackendService.login(username, password);

      if (result['success'] == true) {
        final data = result['data'];
        String? token;
        if (data is Map) {
          token = data['accessToken']?.toString();
        }

        if (token == null || token.isEmpty) {
          _isLoading = false;
          notifyListeners();
          return {'success': false, 'message': 'No token received from server'};
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', username);
        await prefs.setString('auth_token', token);

        _currentUser = username;
        _authToken = token;
        _isLoading = false;
        notifyListeners();
        return {'success': true};
      } else {
        _isLoading = false;
        notifyListeners();
        return result;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> signup(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await BackendService.signup(username, password);

      if (result['success'] == true) {
        final loginResult = await login(username, password);
        return loginResult;
      } else {
        _isLoading = false;
        notifyListeners();
        return result;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('auth_token');

    _currentUser = null;
    _authToken = null;
    _avatarUrl = null;
    notifyListeners();
  }

  Future<void> loadUserProfile() async {
    try {
      final result = await BackendService.getUserProfile();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        _avatarUrl = data['avatar_url'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar', data['avatar_url'] ?? '');
        notifyListeners();
      }
    } catch (e) {
      print('AuthProvider.loadUserProfile error: $e');
    }
  }

  void setAvatarUrl(String? url) {
    _avatarUrl = url;
    notifyListeners();
  }
}
