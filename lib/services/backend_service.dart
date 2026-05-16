import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

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

      if (response.statusCode == 403) {
        if (data is Map && data['message']?.toString().contains('expired') == true) {
          final refreshResult = await refreshToken();
          if (refreshResult['success'] == true) {
            return {
              'success': false,
              'message': 'Token refreshed, please retry.',
              'data': null,
              'tokenRefreshed': true,
            };
          }
          await AuthService.logout();
          return {
            'success': false,
            'message': 'Session expired. Please login again.',
            'data': null,
            'tokenExpired': true,
          };
        }
        return {
          'success': false,
          'message': data['message'] ?? 'Request failed',
          'data': null,
        };
      }

      if (data is List) {
        return {
          'success': true,
          'message': 'Success',
          'data': data,
        };
      }

      return {
        'success': false,
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
      {String? imageUrl, String? parentCommentId, String? movieTitle}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'movieId': movieId,
        'content': content,
      };
      if (imageUrl != null) {
        body['imageUrl'] = imageUrl;
      }
      if (parentCommentId != null) {
        body['parentCommentId'] = parentCommentId;
      }
      if (movieTitle != null) {
        body['movieTitle'] = movieTitle;
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

  static Future<Map<String, dynamic>> getMovieRating(int movieId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/ratings/movie/$movieId'),
        headers: headers,
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

  static Future<Map<String, dynamic>> getBatchMovieRatings(List<int> movieIds) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/ratings/batch'),
        headers: headers,
        body: jsonEncode({'movieIds': movieIds}),
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

  static Future<Map<String, dynamic>> submitRating(int movieId, double score, {String? moviePoster}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'movieId': movieId,
        'score': score,
      };
      if (moviePoster != null) body['moviePoster'] = moviePoster;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/ratings'),
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

  static Future<Map<String, dynamic>> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return {'success': false};

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Authorization': 'Bearer $refreshToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = data['accessToken']?.toString();
        if (newToken != null) {
          await prefs.setString('auth_token', newToken);
          return {'success': true, 'data': data};
        }
      }
      return {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  static Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final contentType = response.headers['content-type'];
    if (contentType == null || !contentType.contains('application/json')) {
      return {
        'success': false,
        'message': 'Server error (Status: ${response.statusCode}) - ${response.body}',
        'data': null,
      };
    }

    try {
      final data = jsonDecode(response.body);

      if (response.statusCode == 403 &&
          data['message']?.toString().contains('expired') == true) {
        final refreshResult = await refreshToken();
        if (refreshResult['success'] == true) {
          return {
            'success': false,
            'message': 'Token refreshed, please retry.',
            'data': null,
            'tokenRefreshed': true,
          };
        }
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
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Server error (Status: ${response.statusCode}) - ${response.body}',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> updateAvatar(File avatarFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Chưa đăng nhập',
          'data': null,
        };
      }

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$_baseUrl/api/users/avatar'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      final extension = avatarFile.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png'
          ? 'image/png'
          : extension == 'gif'
              ? 'image/gif'
              : extension == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          avatarFile.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 502 || response.statusCode == 503) {
        return {
          'success': false,
          'message': 'Server đang khởi động, vui lòng thử lại sau 1-2 phút',
          'data': null,
        };
      }

      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/profile'),
        headers: headers,
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

  static Future<Map<String, dynamic>> changeUsername(String currentPassword, String newUsername) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/api/users/change-username'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newUsername': newUsername,
        }),
      );
      final result = await _handleResponse(response);
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map;
        if (data['accessToken'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['accessToken'].toString());
          await prefs.setString('current_user', data['username'].toString());
        }
      }
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/api/users/change-password'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
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

  static Future<Map<String, dynamic>> deleteComment(String commentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/comments/$commentId'),
        headers: headers,
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

  static Future<Map<String, dynamic>> toggleLikeComment(String commentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/comments/$commentId/like'),
        headers: headers,
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

  static Future<Map<String, dynamic>> getReports() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/reports'),
        headers: headers,
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

  static Future<Map<String, dynamic>> deleteReport(String reportId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/reports/$reportId'),
        headers: headers,
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

  static Future<Map<String, dynamic>> deleteUser(String username) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/users/$username'),
        headers: headers,
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

  static Future<Map<String, dynamic>> getNotifications() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/notifications'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/notifications/unread-count'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/notifications/read-all'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/notifications/$id/read'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/notifications/$id'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> sendNotice(String username, {String? commentContent}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{'username': username};
      if (commentContent != null) body['commentContent'] = commentContent;
      final response = await http.post(
        Uri.parse('$_baseUrl/api/reports/notice'),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> reportComment(String username, String message, {String? commentContent}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'username': username,
        'message': message,
      };
      if (commentContent != null) body['commentContent'] = commentContent;
      final response = await http.post(
        Uri.parse('$_baseUrl/api/reports'),
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

  static Future<Map<String, dynamic>> uploadCommentImage(File imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Chưa đăng nhập',
          'data': null,
        };
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/comments/upload-image'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      final extension = imageFile.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png'
          ? 'image/png'
          : extension == 'gif'
              ? 'image/gif'
              : extension == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'commentImage',
          imageFile.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi kết nối: $e',
        'data': null,
      };
    }
  }
}
