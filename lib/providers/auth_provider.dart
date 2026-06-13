import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../services/backend_service.dart';
import '../services/secure_storage_service.dart';

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
    _currentUser = await SecureStorageService.getCurrentUser();
    _authToken = await SecureStorageService.getAuthToken();
    final rawAvatar = await SecureStorageService.getUserAvatar();
    _avatarUrl = ApiConfig.normalizeUrl(rawAvatar);
    _userId = await SecureStorageService.getUserId();
    _role = await SecureStorageService.getUserRole();
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

        await SecureStorageService.saveCurrentUser(username);
        await SecureStorageService.saveAuthToken(token);
        if (refreshToken != null) await SecureStorageService.saveRefreshToken(refreshToken);
        if (userId != null) await SecureStorageService.saveUserId(userId);
        if (role != null) await SecureStorageService.saveUserRole(role);
        if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.contains('thenounproject.com')) {
          final normalized = ApiConfig.normalizeUrl(avatarUrl);
          await SecureStorageService.saveUserAvatar(normalized);
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
    await SecureStorageService.clearAll();

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
        final raw = data['avatar_url']?.toString() ?? '';
        final userRole = data['role']?.toString();
        _avatarUrl = (raw.isNotEmpty && !raw.contains('thenounproject.com'))
            ? ApiConfig.normalizeUrl(raw) : null;
        if (userRole != null) {
          _role = userRole;
          await SecureStorageService.saveUserRole(userRole);
        }
        await SecureStorageService.saveUserAvatar(_avatarUrl ?? '');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AuthProvider.loadUserProfile error: $e');
    }
  }

  void setAvatarUrl(String? url) {
    _avatarUrl = ApiConfig.normalizeUrl(url);
    notifyListeners();
  }
}
