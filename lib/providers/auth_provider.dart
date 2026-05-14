import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/backend_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _currentUser;
  String? _authToken;
  String? _avatarUrl;
  String? _userId;
  bool _isLoading = false;

  String? get currentUser => _currentUser;
  String? get authToken => _authToken;
  String? get avatarUrl => _avatarUrl;
  String? get userId => _userId;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('current_user');
    _authToken = prefs.getString('auth_token');
    _avatarUrl = ApiConfig.normalizeUrl(prefs.getString('user_avatar'));
    _userId = prefs.getString('user_id');
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
        String? userId;
        String? avatarUrl;
        if (data is Map) {
          token = data['accessToken']?.toString();
          userId = data['userId']?.toString();
          avatarUrl = data['avatar_url']?.toString();
        }

        if (token == null || token.isEmpty) {
          _isLoading = false;
          notifyListeners();
          return {'success': false, 'message': 'No token received from server'};
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', username);
        await prefs.setString('auth_token', token);
        if (userId != null) await prefs.setString('user_id', userId);
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          final normalized = ApiConfig.normalizeUrl(avatarUrl);
          await prefs.setString('user_avatar', normalized);
          _avatarUrl = normalized;
        }

        _currentUser = username;
        _authToken = token;
        _userId = userId;
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
    await prefs.remove('user_id');
    await prefs.remove('user_avatar');

    _currentUser = null;
    _authToken = null;
    _avatarUrl = null;
    _userId = null;
    notifyListeners();
  }

  Future<void> loadUserProfile() async {
    try {
      final result = await BackendService.getUserProfile();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final rawUrl = data['avatar_url']?.toString() ?? '';
        _avatarUrl = ApiConfig.normalizeUrl(rawUrl);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar', _avatarUrl ?? '');
        notifyListeners();
      }
    } catch (e) {
      print('AuthProvider.loadUserProfile error: $e');
    }
  }

  void setAvatarUrl(String? url) {
    _avatarUrl = ApiConfig.normalizeUrl(url);
    notifyListeners();
  }
}
