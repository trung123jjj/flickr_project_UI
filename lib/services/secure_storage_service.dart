import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _keyCurrentUser = 'current_user';
  static const _keyAuthToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyUserRole = 'user_role';
  static const _keyUserAvatar = 'user_avatar';

  static Future<void> saveCurrentUser(String value) async {
    await _storage.write(key: _keyCurrentUser, value: value);
  }

  static Future<String?> getCurrentUser() async {
    return await _storage.read(key: _keyCurrentUser);
  }

  static Future<void> saveAuthToken(String value) async {
    await _storage.write(key: _keyAuthToken, value: value);
  }

  static Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyAuthToken);
  }

  static Future<void> saveRefreshToken(String value) async {
    await _storage.write(key: _keyRefreshToken, value: value);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  static Future<void> saveUserId(String value) async {
    await _storage.write(key: _keyUserId, value: value);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  static Future<void> saveUserRole(String value) async {
    await _storage.write(key: _keyUserRole, value: value);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  static Future<void> saveUserAvatar(String value) async {
    await _storage.write(key: _keyUserAvatar, value: value);
  }

  static Future<String?> getUserAvatar() async {
    return await _storage.read(key: _keyUserAvatar);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  static Future<void> remove(String key) async {
    await _storage.delete(key: key);
  }
}
