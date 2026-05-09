import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import '../models/movie.dart';
import '../models/genre.dart';
import '../services/tmdb_service.dart';
import '../services/backend_service.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Movie> _popularMovies = [];
  List<Movie> _nowPlayingMovies = [];
  List<Genre> _genres = [];
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  String? _loadError;
  final PageController _pageController = PageController(viewportFraction: 0.9);
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  List<Movie> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    auth.loadUserProfile();
    _loadAllData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      final tmdbResults = await Future.wait([
        TmdbService.getPopularMovies(),
        TmdbService.getNowPlayingMovies(),
        TmdbService.getGenres(),
      ]);
      final popular = tmdbResults[0] as List<Movie>;
      final nowPlaying = tmdbResults[1] as List<Movie>;
      final genresList = tmdbResults[2] as List<Genre>;

      final allMovieIds = <int>{};
      for (var m in popular) { allMovieIds.add(m.id); }
      for (var m in nowPlaying) { allMovieIds.add(m.id); }

      final ratingsFuture = allMovieIds.isNotEmpty
          ? BackendService.getBatchMovieRatings(allMovieIds.toList())
          : Future.value(<String, dynamic>{'success': false, 'data': null});

      final usedBackdrops = <String>{};
      for (var genre in genresList) {
        try {
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
        } catch (e) {
          print('Error loading backdrop for genre ${genre.id}: $e');
        }
      }

      Map<int, dynamic> ratings = {};
      final result = await ratingsFuture;
      if (result['success'] == true) {
        final data = result['data'];
        if (data != null) {
          (data as Map).forEach((key, value) {
            ratings[int.parse(key.toString())] = value;
          });
        }
      }

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

      final hasData = popular.isNotEmpty || nowPlaying.isNotEmpty || genresList.isNotEmpty;

      setState(() {
        _popularMovies = popular.map((m) => updateMovieRating(m, ratings)).toList();
        _nowPlayingMovies = nowPlaying.map((m) => updateMovieRating(m, ratings)).toList();
        _genres = genresList;
        _loadError = hasData ? null : 'Failed to load data. Please check your internet connection and try again.';
        _isLoading = false;
      });
    } catch (e) {
      print('HomeScreen._loadAllData error: $e');
      setState(() {
        _loadError = 'Failed to load data. Please check your internet connection and try again.';
        _isLoading = false;
      });
    }
  }

  void _applyRatingUpdate(Map result) {
    final movieId = result['movieId'] as int;
    final avgRating = (result['averageRating'] as num?)?.toDouble();
    final totalRatings = result['totalRatings'] as int?;
    setState(() {
      _popularMovies = _popularMovies.map((m) {
        if (m.id == movieId) {
          return Movie(
            id: m.id, title: m.title, overview: m.overview,
            posterPath: m.posterPath, backdropPath: m.backdropPath,
            voteAverage: m.voteAverage, releaseDate: m.releaseDate,
            genreIds: m.genreIds,
            averageRating: avgRating ?? m.averageRating,
            totalRatings: totalRatings ?? m.totalRatings,
          );
        }
        return m;
      }).toList();
      _nowPlayingMovies = _nowPlayingMovies.map((m) {
        if (m.id == movieId) {
          return Movie(
            id: m.id, title: m.title, overview: m.overview,
            posterPath: m.posterPath, backdropPath: m.backdropPath,
            voteAverage: m.voteAverage, releaseDate: m.releaseDate,
            genreIds: m.genreIds,
            averageRating: avgRating ?? m.averageRating,
            totalRatings: totalRatings ?? m.totalRatings,
          );
        }
        return m;
      }).toList();
    });
  }

  Future<void> _refreshRatingsOnly() async {
    final allMovieIds = <int>{};
    for (var m in _popularMovies) { allMovieIds.add(m.id); }
    for (var m in _nowPlayingMovies) { allMovieIds.add(m.id); }
    if (allMovieIds.isEmpty) return;

    final result = await BackendService.getBatchMovieRatings(allMovieIds.toList());
    if (!mounted) return;

    Map<int, dynamic> ratings = {};
    if (result['success'] == true) {
      final data = result['data'];
      if (data != null) {
        (data as Map).forEach((key, value) {
          ratings[int.parse(key.toString())] = value;
        });
      }
    }

    Movie updateMovieRating(Movie movie, Map<int, dynamic> ratings) {
      final r = ratings[movie.id];
      return Movie(
        id: movie.id, title: movie.title, overview: movie.overview,
        posterPath: movie.posterPath, backdropPath: movie.backdropPath,
        voteAverage: movie.voteAverage, releaseDate: movie.releaseDate,
        genreIds: movie.genreIds,
        averageRating: r != null ? (r['averageScore'] ?? 0).toDouble() : null,
        totalRatings: r != null ? r['totalRatings'] ?? 0 : 0,
      );
    }

    setState(() {
      _popularMovies = _popularMovies.map((m) => updateMovieRating(m, ratings)).toList();
      _nowPlayingMovies = _nowPlayingMovies.map((m) => updateMovieRating(m, ratings)).toList();
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _isSearchLoading = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 500), () => _performSearch(query.trim()));
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearchLoading = true);
    final results = await TmdbService.searchMovies(query);
    if (!mounted) return;

    if (results.isNotEmpty) {
      final movieIds = results.map((m) => m.id).toList();
      final ratingsResult = await BackendService.getBatchMovieRatings(movieIds);
      if (mounted && ratingsResult['success'] == true) {
        final data = ratingsResult['data'];
        Map<int, dynamic> ratings = {};
        if (data != null) {
          (data as Map).forEach((key, value) {
            ratings[int.parse(key.toString())] = value;
          });
        }
        setState(() {
          _searchResults = results.map((m) {
            final r = ratings[m.id];
            return Movie(
              id: m.id, title: m.title, overview: m.overview,
              posterPath: m.posterPath, backdropPath: m.backdropPath,
              voteAverage: m.voteAverage, releaseDate: m.releaseDate,
              genreIds: m.genreIds,
              averageRating: r != null ? (r['averageScore'] ?? 0).toDouble() : null,
              totalRatings: r != null ? r['totalRatings'] ?? 0 : 0,
            );
          }).toList();
          _isSearchLoading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _isSearchLoading = false;
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
        if (mounted) {
          context.read<AuthProvider>().loadUserProfile();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated successfully!'),
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
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _loadError = null;
                            });
                            _loadAllData();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildSearchBar(),
              if (_isSearching) ...[
                if (_isSearchLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF87CEEB))),
                  )
                else if (_searchResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No movies found', style: TextStyle(color: Colors.white54, fontSize: 16))),
                  )
                else
                  _buildMovieListHorizontal(_searchResults),
              ] else ...[
                _buildSectionTitle('Now Playing'),
                _buildNowPlayingLarge(_nowPlayingMovies),
                _buildSectionTitle('Popular'),
                _buildMovieListHorizontal(_popularMovies),
                _buildSectionTitle('Genres'),
                _buildGenreListHorizontal(_genres),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final auth = context.watch<AuthProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text('Hello, ${auth.currentUser ?? ""}!',
                style: const TextStyle(color: Color(0xFF87CEEB), fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                onPressed: () async {
                  await auth.logout();
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
                      backgroundImage: auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(auth.avatarUrl!)
                          : const AssetImage('assets/images/profile_pic.png') as ImageProvider,
                      child: auth.avatarUrl == null || auth.avatarUrl!.isEmpty
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search movies...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF1B263B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
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
          return GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/genreMovies', arguments: {
                'genreId': genre.id,
                'genreName': genre.name,
              });
            },
            child: Container(
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
                onTap: () async {
                  final result = await Navigator.pushNamed(context, '/details', arguments: movie);
                  if (!mounted) return;
                  if (result is Map && result['updatedRating'] == true) {
                    _applyRatingUpdate(result);
                    _refreshRatingsOnly();
                  } else {
                    _loadAllData();
                  }
                },
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
             onTap: () async {
                final result = await Navigator.pushNamed(context, '/details', arguments: movie);
                if (!mounted) return;
                if (result is Map && result['updatedRating'] == true) {
                  _applyRatingUpdate(result);
                  _refreshRatingsOnly();
                } else {
                  _loadAllData();
                }
              },
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
