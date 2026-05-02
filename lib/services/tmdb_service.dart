import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/genre.dart';
import '../models/cast.dart';
import '../config/api_config.dart';

class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static Map<int, String> _genreMap = {};

  static Map<String, String> get _headers => {
    'Authorization': 'Bearer ${ApiConfig.tmdbAccessToken}',
    'Content-Type': 'application/json',
  };

  // Khởi tạo Genres
  static Future<void> initGenres() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/genre/movie/list?language=en-US'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['genres'];
        for (var item in results) { _genreMap[item['id']] = item['name']; }
      }
    } catch (e) {}
  }

  static List<String> getGenreNames(List<int> ids) {
    return ids.map((id) => _genreMap[id] ?? 'Unknown').toList();
  }

  // Lấy mã YouTube Trailer
  static Future<String?> getMovieTrailerKey(int movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/$movieId/videos?language=en-US'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        // Tìm video có type là 'Trailer' và từ 'YouTube'
        final trailer = results.firstWhere(
          (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
          orElse: () => results.isNotEmpty ? results[0] : null,
        );
        return trailer != null ? trailer['key'] : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Cast>> getMovieCast(int movieId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/movie/$movieId/credits?language=en-US'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List castList = data['cast'];
        return castList.take(10).map((json) => Cast.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<Map<String, dynamic>?> getActorDetails(int personId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/person/$personId?language=en-US'), headers: _headers);
      if (response.statusCode == 200) { return jsonDecode(response.body); }
      return null;
    } catch (e) { return null; }
  }

  static Future<List<Genre>> getGenres() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/genre/movie/list?language=en-US'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['genres'];
        return results.map((json) => Genre.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<List<String>> getBackdropListForGenre(int genreId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/discover/movie?with_genres=$genreId&language=en-US&sort_by=popularity.desc&page=1'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        return results.where((m) => m['backdrop_path'] != null).map((m) => 'https://image.tmdb.org/t/p/w500${m['backdrop_path']}').toList();
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<List<Movie>> getPopularMovies() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/movie/popular?language=en-US&page=1'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        return results.map((json) => Movie.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<List<Movie>> getNowPlayingMovies() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/movie/now_playing?language=en-US&page=1'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'];
        return results.map((json) => Movie.fromJson(json)).toList();
      }
      return [];
    } catch (e) { return []; }
  }
}
