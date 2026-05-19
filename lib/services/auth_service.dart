import 'package:flutter/material.dart';
import 'secure_storage_service.dart';

class AuthService {
  static Future<void> logout() async {
    await SecureStorageService.remove('current_user');
    await SecureStorageService.remove('auth_token');
  }

  static Future<bool> isLoggedIn() async {
    final user = await SecureStorageService.getCurrentUser();
    return user != null;
  }

  static Future<String?> getCurrentUser() async {
    return await SecureStorageService.getCurrentUser();
  }
}
