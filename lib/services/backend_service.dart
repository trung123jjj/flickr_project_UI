import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

class BackendService {
  static String get _baseUrl => ApiConfig.backendBaseUrl;

  static Future<Map<String, dynamic>> signup(String username, String password) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/signup'),
        headers: headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/signin'),
        headers: headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> getComments(int movieId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/comments/$movieId'),
        headers: headers,
      );

      final contentType = response.headers['content-type'];
      if (contentType == null || !contentType.contains('application/json')) {
        return {
          'success': false,
          'message': 'Server error (Status: ${response.statusCode})',
          'data': null,
        };
      }

      final data = jsonDecode(response.body);

      // Backend returns array directly
      if (data is List) {
        return {
          'success': true,
          'message': 'Success',
          'data': data,
        };
      }

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Failed to load comments',
        'data': data,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> createComment(int movieId, String content,
      {String? imageUrl}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'movieId': movieId,
        'content': content,
      };
      if (imageUrl != null) {
        body['imageUrl'] = imageUrl;
      }
      final response = await http.post(
        Uri.parse('$_baseUrl/api/comments'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty && token != 'null') {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final contentType = response.headers['content-type'];
    if (contentType == null || !contentType.contains('application/json')) {
      return {
        'success': false,
        'message': 'Server error (Status: ${response.statusCode})',
        'data': null,
      };
    }

    final data = jsonDecode(response.body);

    if (response.statusCode == 403 &&
        data['message']?.toString().contains('expired') == true) {
      await AuthService.logout();
      return {
        'success': false,
        'message': 'Session expired. Please login again.',
        'data': null,
        'tokenExpired': true,
      };
    }

    return {
      'success': response.statusCode >= 200 && response.statusCode < 300,
      'message': data['message'] ?? 'Request failed (Status: ${response.statusCode})',
      'data': data,
      'token': data['accessToken'] ?? data['token'],
    };
  }
}
