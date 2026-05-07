import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/movie.dart';
import '../models/genre.dart';
import '../services/tmdb_service.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  String _username = '';
  String? _avatarUrl;
  List<Movie> _popularMovies = [];
  List<Movie> _nowPlayingMovies = [];
  List<Genre> _genres = [];
  Map<int, dynamic> _movieRatings = {};
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  final PageController _pageController = PageController(viewportFraction: 0.9);
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadUserProfile();
    _loadAllData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('current_user') ?? '';
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final result = await BackendService.getUserProfile();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        setState(() {
          _avatarUrl = data['avatar_url'];
        });
        // Save avatar URL to preferences for use in comments
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar', data['avatar_url'] ?? '');
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _loadAllData() async {
    final popular = await TmdbService.getPopularMovies();
    final nowPlaying = await TmdbService.getNowPlayingMovies();
    final genresList = await TmdbService.getGenres();

    final usedBackdrops = <String>{};
    for (var genre in genresList) {
      final potentialBackdrops = await TmdbService.getBackdropListForGenre(genre.id);
      String? chosenBackdrop;
      for (var url in potentialBackdrops) {
        if (!usedBackdrops.contains(url)) {
          chosenBackdrop = url;
          usedBackdrops.add(url);
          break;
        }
      }
      genre.backdropUrl = chosenBackdrop ?? (potentialBackdrops.isNotEmpty ? potentialBackdrops[0] : null);
    }

    // Lấy tất cả movieIds để fetch rating 1 lần
    final allMovieIds = <int>{};
    for (var m in popular) { allMovieIds.add(m.id); }
    for (var m in nowPlaying) { allMovieIds.add(m.id); }

    Map<int, dynamic> ratings = {};
    if (allMovieIds.isNotEmpty) {
      final result = await BackendService.getBatchMovieRatings(allMovieIds.toList());
      if (result['success'] == true) {
        final data = result['data'];
        if (data != null) {
          (data as Map).forEach((key, value) {
            ratings[int.parse(key.toString())] = value;
          });
        }
      }
    }

    // Cập nhật rating cho từng phim
    Movie updateMovieRating(Movie movie, Map<int, dynamic> ratings) {
      final r = ratings[movie.id];
      return Movie(
        id: movie.id,
        title: movie.title,
        overview: movie.overview,
        posterPath: movie.posterPath,
        backdropPath: movie.backdropPath,
        voteAverage: movie.voteAverage,
        releaseDate: movie.releaseDate,
        genreIds: movie.genreIds,
        averageRating: r != null ? (r['averageScore'] ?? 0).toDouble() : null,
        totalRatings: r != null ? r['totalRatings'] ?? 0 : 0,
      );
    }

    setState(() {
      _popularMovies = popular.map((m) => updateMovieRating(m, ratings)).toList();
      _nowPlayingMovies = nowPlaying.map((m) => updateMovieRating(m, ratings)).toList();
      _genres = genresList;
      _movieRatings = ratings;
      _isLoading = false;
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    await _selectAndUploadImage();
  }

  Future<void> _selectAndUploadImage() async {
    try {
      // Kiểm tra và xin quyền truy cập ảnh
      Permission permission = Platform.isAndroid 
          ? Permission.mediaLibrary 
          : Permission.photos;
      
      PermissionStatus status = await permission.status;
      
      if (status.isDenied) {
        status = await permission.request();
      }
      
      if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1B263B),
              title: const Text('Cần cấp quyền', style: TextStyle(color: Colors.white)),
              content: const Text(
                'Ứng dụng cần quyền truy cập thư viện ảnh để đổi avatar.\n\n'
                'Vui lòng vào Cài đặt > Ứng dụng > Flickr Project > Quyền hạn để cấp quyền.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Để sau', style: TextStyle(color: Color(0xFF87CEEB))),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Mở cài đặt', style: TextStyle(color: Color(0xFF87CEEB))),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      if (!status.isGranted) {
        throw Exception('permission_denied');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      ).catchError((e) {
        throw e;
      });

      if (image == null) return;

      setState(() => _isUploadingAvatar = true);

      final result = await BackendService.updateAvatar(File(image.path));

      if (result['success'] == true) {
        await _loadUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật avatar thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update avatar'),
              backgroundColor: const Color(0xFFFF6B00),
            ),
          );
        }
      }
    } catch (e) {
      String message = 'Không thể mở thư viện ảnh';
      
      // Kiểm tra nếu là lỗi quyền
      final error = e.toString().toLowerCase();
      if (error.contains('permission') || 
          error.contains('platformexception') ||
          error.contains('denied')) {
        message = 'Chưa cấp quyền truy cập ảnh.\n\n'
            'Cách khắc phục:\n'
            '1. Gỡ cài đặt app này\n'
            '2. Cài lại app\n'
            '3. Khi app hỏi quyền, bấm "Cho phép"';
      }
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1B263B),
            title: const Text('Lỗi', style: TextStyle(color: Colors.white)),
            content: Text(message, style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu', style: TextStyle(color: Color(0xFF87CEEB))),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF87CEEB)))
          : SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildSectionTitle('Now Playing'),
              _buildNowPlayingLarge(_nowPlayingMovies),
              _buildSectionTitle('Popular'),
              _buildMovieListHorizontal(_popularMovies),
              _buildSectionTitle('Genres'),
              _buildGenreListHorizontal(_genres),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text('Xin chào, $_username!',
                style: const TextStyle(color: Color(0xFF87CEEB), fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                onPressed: () async {
                  await AuthService.logout();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  }
                },
              ),
              GestureDetector(
                onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(_avatarUrl!)
                          : const AssetImage('assets/images/profile_pic.png') as ImageProvider,
                      child: _avatarUrl == null || _avatarUrl!.isEmpty
                          ? const Icon(Icons.person, color: Colors.white70, size: 30)
                          : null,
                    ),
                    if (_isUploadingAvatar)
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.black54,
                        child: CircularProgressIndicator(
                          color: Color(0xFF87CEEB),
                          strokeWidth: 2,
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B00),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 25, 30, 15),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGenreListHorizontal(List<Genre> genres) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 16),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: CachedNetworkImage(
                    imageUrl: genre.backdropUrl ?? '',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(color: Colors.blueGrey),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: Center(
                    child: Text(
                      genre.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNowPlayingLarge(List<Movie> movies) {
    return SizedBox(
      height: 400,
      child: PageView.builder(
        controller: _pageController,
        itemCount: movies.length > 5 ? 5 : movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/details', arguments: movie).then((_) {
                  if (mounted) _loadAllData();
                }),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(imageUrl: movie.posterUrl, fit: BoxFit.cover),
                    Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
                    Positioned(
                      bottom: 25, left: 20, right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        Row(children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            movie.averageRating != null && movie.averageRating! > 0
                                ? movie.averageRating!.toStringAsFixed(1)
                                : '0.0',
                            style: const TextStyle(color: Colors.amber, fontSize: 18)
                          ),
                          if (movie.totalRatings != null && movie.totalRatings! > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${movie.totalRatings})',
                              style: const TextStyle(color: Colors.white70, fontSize: 14)
                            ),
                          ],
                        ]),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovieListHorizontal(List<Movie> movies) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: movies.length,
        itemBuilder: (context, index) {
          final movie = movies[index];
          return GestureDetector(
             onTap: () => Navigator.pushNamed(context, '/details', arguments: movie).then((_) {
               if (mounted) _loadAllData();
             }),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: movie.posterUrl, fit: BoxFit.cover))),
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Row(children: [
                    const Icon(Icons.star, color: Color(0xFFFFAB40), size: 14), 
                    const SizedBox(width: 4), 
                    Text(
                      movie.averageRating != null && movie.averageRating! > 0
                          ? movie.averageRating!.toStringAsFixed(1)
                          : '0.0',
                      style: const TextStyle(color: Color(0xFFFFAB40), fontSize: 13)
                    ),
                    if (movie.totalRatings != null && movie.totalRatings! > 0) ...[
                      const SizedBox(width: 2),
                      Text(
                        '(${movie.totalRatings})',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
