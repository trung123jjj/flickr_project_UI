import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
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
  String? _loadError;
  final PageController _pageController = PageController(viewportFraction: 0.9);
  final TextEditingController _searchController = TextEditingController();
  List<Movie> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;
  Timer? _searchDebounce;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    auth.loadUserProfile();
    _loadAllData();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final result = await BackendService.getUnreadCount();
    if (mounted) {
      final data = result['data'] as Map<String, dynamic>?;
      final count = data?['unreadCount'];
      if (result['success'] == true) {
        setState(() => _unreadCount = (count as int? ?? 0));
      }
    }
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

      final hasData = popular.isNotEmpty || nowPlaying.isNotEmpty || genresList.isNotEmpty;

      setState(() {
        _popularMovies = popular;
        _nowPlayingMovies = nowPlaying;
        _genres = genresList;
        _loadError = hasData ? null : 'Failed to load data. Please check your internet connection and try again.';
        _isLoading = false;
      });

      _loadRatingsForMovies(popular, nowPlaying);
    } catch (e) {
      print('HomeScreen._loadAllData error: $e');
      setState(() {
        _loadError = 'Failed to load data. Please check your internet connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRatingsForMovies(List<Movie> popular, List<Movie> nowPlaying) async {
    try {
      final allMovieIds = <int>{};
      for (var m in popular) { allMovieIds.add(m.id); }
      for (var m in nowPlaying) { allMovieIds.add(m.id); }

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

      if (!mounted) return;
      setState(() {
        _popularMovies = popular.map((m) => _applyRating(m, ratings)).toList();
        _nowPlayingMovies = nowPlaying.map((m) => _applyRating(m, ratings)).toList();
      });
    } catch (e) {
      print('HomeScreen._loadRatingsForMovies error: $e');
    }
  }

  Movie _applyRating(Movie movie, Map<int, dynamic> ratings) {
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

  void _applyRatingUpdate(Map result) {
    final movieId = result['movieId'] as int;
    final avgRating = (result['averageRating'] as num?)?.toDouble();
    final totalRatings = result['totalRatings'] as int?;

    final ratings = {movieId: {'averageScore': avgRating, 'totalRatings': totalRatings}};

    if (mounted) {
      setState(() {
        _popularMovies = _popularMovies.map((m) => _applyRating(m, ratings)).toList();
        _nowPlayingMovies = _nowPlayingMovies.map((m) => _applyRating(m, ratings)).toList();
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _loadError != null
              ? _buildErrorView()
              : SafeArea(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _HomeHeader(unreadCount: _unreadCount, onRefresh: _loadUnreadCount)),
                      SliverToBoxAdapter(child: _buildSearchBar()),
                      if (_isSearching)
                        _buildSearchSliver()
                      else ...[
                        const SliverToBoxAdapter(child: _SectionTitle(title: 'Now Playing')),
                        SliverToBoxAdapter(child: _buildNowPlayingLarge(_nowPlayingMovies)),
                        const SliverToBoxAdapter(child: _SectionTitle(title: 'Popular')),
                        SliverToBoxAdapter(child: _buildMovieListHorizontal(_popularMovies)),
                        const SliverToBoxAdapter(child: _SectionTitle(title: 'Genres')),
                        SliverToBoxAdapter(child: _buildGenreListHorizontal(_genres)),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() { _isLoading = true; _loadError = null; });
                _loadAllData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSliver() {
    if (_isSearchLoading) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))));
    if (_searchResults.isEmpty) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No movies found', style: TextStyle(color: Colors.white54, fontSize: 16)))));
    return SliverToBoxAdapter(child: _buildMovieListHorizontal(_searchResults));
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search movies...',
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15)), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildGenreListHorizontal(List<Genre> genres) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: genres.length,
        itemExtent: 216,
        itemBuilder: (context, index) {
          return RepaintBoundary(child: _GenreCard(genre: genres[index]));
        },
      ),
    );
  }

  Widget _buildNowPlayingLarge(List<Movie> movies) {
    final itemCount = movies.length > 5 ? 5 : movies.length;
    return SizedBox(
      height: 400,
      child: PageView.builder(
        controller: _pageController,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: _NowPlayingCard(
              movie: movies[index],
              onRatingUpdate: (movieId, avgRating, totalRatings) {
                if (mounted) _applyRatingUpdate({'movieId': movieId, 'averageRating': avgRating, 'totalRatings': totalRatings});
              },
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
        itemExtent: 156,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: _MovieCard(
              movie: movies[index],
              onRatingUpdate: (movieId, avgRating, totalRatings) {
                if (mounted) _applyRatingUpdate({'movieId': movieId, 'averageRating': avgRating, 'totalRatings': totalRatings});
              },
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 25, 30, 15),
      child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }
}

typedef _RatingUpdateCallback = void Function(int movieId, double? avgRating, int? totalRatings);

class _NowPlayingCard extends StatelessWidget {
  final Movie movie;
  final _RatingUpdateCallback onRatingUpdate;

  const _NowPlayingCard({required this.movie, required this.onRatingUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GestureDetector(
          onTap: () async {
            final result = await Navigator.pushNamed(context, '/details', arguments: movie);
            if (context.mounted && result is Map && result['updatedRating'] == true) {
              Future.delayed(const Duration(milliseconds: 350), () {
                if (context.mounted) {
                  onRatingUpdate(result['movieId'] as int, (result['averageRating'] as num?)?.toDouble(), result['totalRatings'] as int?);
                }
              });
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: movie.getPosterUrl('w500'),
                fit: BoxFit.cover,
                memCacheWidth: 600,
                placeholder: (context, url) => Container(color: Colors.grey[900]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
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
                    Text(movie.averageRating != null && movie.averageRating! > 0 ? movie.averageRating!.toStringAsFixed(1) : '0.0', style: const TextStyle(color: Colors.amber, fontSize: 18)),
                    if (movie.totalRatings != null && movie.totalRatings! > 0) ...[
                      const SizedBox(width: 4),
                      Text('(${movie.totalRatings})', style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
  }
}

class _MovieCard extends StatelessWidget {
  final Movie movie;
  final _RatingUpdateCallback onRatingUpdate;

  const _MovieCard({required this.movie, required this.onRatingUpdate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.pushNamed(context, '/details', arguments: movie);
        if (context.mounted && result is Map && result['updatedRating'] == true) {
          Future.delayed(const Duration(milliseconds: 350), () {
            if (context.mounted) {
              onRatingUpdate(result['movieId'] as int, (result['averageRating'] as num?)?.toDouble(), result['totalRatings'] as int?);
            }
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: CachedNetworkImage(
                  imageUrl: movie.getPosterUrl('w342'),
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  placeholder: (context, url) => Container(color: Colors.grey[900]),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(movie.title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Row(children: [
              const Icon(Icons.star, color: Color(0xFFFFAB40), size: 14),
              const SizedBox(width: 4),
              Text(movie.averageRating != null && movie.averageRating! > 0 ? movie.averageRating!.toStringAsFixed(1) : '0.0', style: const TextStyle(color: Color(0xFFFFAB40), fontSize: 13)),
              if (movie.totalRatings != null && movie.totalRatings! > 0) ...[
                const SizedBox(width: 2),
                Text('(${movie.totalRatings})', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onRefresh;

  const _HomeHeader({required this.unreadCount, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text('Hello, ${auth.currentUser ?? ""}!',
                style: const TextStyle(color: Color(0xFFE53935), fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(context, '/notifications');
                  onRefresh();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                    if (unreadCount > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/settings'),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: auth.avatarUrl != null && auth.avatarUrl!.isNotEmpty ? CachedNetworkImageProvider(auth.avatarUrl!) : null,
                  child: auth.avatarUrl == null || auth.avatarUrl!.isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 22) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenreCard extends StatefulWidget {
  final Genre genre;
  const _GenreCard({required this.genre});
  @override
  State<_GenreCard> createState() => _GenreCardState();
}

class _GenreCardState extends State<_GenreCard> {
  String? _backdropUrl;
  @override
  void initState() {
    super.initState();
    _loadBackdrop();
  }
  Future<void> _loadBackdrop() async {
    try {
      final backdrops = await TmdbService.getBackdropListForGenre(widget.genre.id);
      if (mounted) setState(() => _backdropUrl = backdrops.isNotEmpty ? backdrops[0] : null);
    } catch (_) {}
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/genreMovies', arguments: {'genreId': widget.genre.id, 'genreName': widget.genre.name});
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              if (_backdropUrl != null) CachedNetworkImage(imageUrl: _backdropUrl!, width: double.infinity, height: double.infinity, fit: BoxFit.cover, memCacheWidth: 400),
              Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)), child: Center(child: Text(widget.genre.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
      ),
    );
  }
}
