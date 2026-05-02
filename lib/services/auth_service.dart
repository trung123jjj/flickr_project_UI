import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await prefs.remove('auth_token');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_user') != null;
  }

  static Future<String?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_user');
  }
}
