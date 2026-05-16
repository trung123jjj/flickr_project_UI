import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/backend_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _currentUser;
  String? _authToken;
  String? _avatarUrl;
  String? _userId;
  String? _role;
  bool _isLoading = false;

  String? get currentUser => _currentUser;
  String? get authToken => _authToken;
  String? get avatarUrl => _avatarUrl;
  String? get userId => _userId;
  String? get role => _role;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _role == 'admin';

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('current_user');
    _authToken = prefs.getString('auth_token');
    _avatarUrl = ApiConfig.normalizeUrl(prefs.getString('user_avatar'));
    _userId = prefs.getString('user_id');
    _role = prefs.getString('user_role');
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
        String? refreshToken;
        String? userId;
        String? avatarUrl;
        String? role;
        if (data is Map) {
          token = data['accessToken']?.toString();
          refreshToken = data['refreshToken']?.toString();
          userId = data['userId']?.toString();
          avatarUrl = data['avatar_url']?.toString();
          role = data['role']?.toString();
        }

        if (token == null || token.isEmpty) {
          _isLoading = false;
          notifyListeners();
          return {'success': false, 'message': 'No token received from server'};
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', username);
        await prefs.setString('auth_token', token);
        if (refreshToken != null) await prefs.setString('refresh_token', refreshToken);
        if (userId != null) await prefs.setString('user_id', userId);
        if (role != null) await prefs.setString('user_role', role);
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          final normalized = ApiConfig.normalizeUrl(avatarUrl);
          await prefs.setString('user_avatar', normalized);
          _avatarUrl = normalized;
        }

        _currentUser = username;
        _authToken = token;
        _userId = userId;
        _role = role;
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
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_avatar');
    await prefs.remove('user_role');

    _currentUser = null;
    _authToken = null;
    _avatarUrl = null;
    _userId = null;
    _role = null;
    notifyListeners();
  }

  Future<void> loadUserProfile() async {
    try {
      final result = await BackendService.getUserProfile();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final rawUrl = data['avatar_url']?.toString() ?? '';
        final userRole = data['role']?.toString();
        _avatarUrl = ApiConfig.normalizeUrl(rawUrl);
        if (userRole != null) {
          _role = userRole;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', userRole);
        }
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
