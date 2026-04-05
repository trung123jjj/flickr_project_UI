import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../config/api_config.dart';

class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  static const Map<String, String> _headers = {
    'Authorization': 'Bearer ${ApiConfig.tmdbAccessToken}',
    'Content-Type': 'application/json',
  };

  // Phim phổ biến
  static Future<List<Movie>> getPopularMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/popular?language=en-US&page=1'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        return results.map((json) => Movie.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Phim đang chiếu
  static Future<List<Movie>> getNowPlayingMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/now_playing?language=en-US&page=1'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        return results.map((json) => Movie.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Phim được đánh giá cao
  static Future<List<Movie>> getTopRatedMovies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/top_rated?language=en-US&page=1'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        return results.map((json) => Movie.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Tìm kiếm phim
  static Future<List<Movie>> searchMovies(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search/movie?query=$query&language=en-US'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        return results.map((json) => Movie.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}