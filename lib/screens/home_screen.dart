import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';
import '../models/genre.dart';
import '../services/tmdb_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  String _username = '';
  List<Movie> _popularMovies = [];
  List<Movie> _nowPlayingMovies = [];
  List<Genre> _genres = [];
  bool _isLoading = true;
  final PageController _pageController = PageController(viewportFraction: 0.9);

  @override
  void initState() {
    super.initState();
    _loadUsername();
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
      _username = prefs.getString('username') ?? '';
    });
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

    setState(() {
      _popularMovies = popular;
      _nowPlayingMovies = nowPlaying;
      _genres = genresList;
      _isLoading = false;
    });
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
          Text('Xin chào, $_username!',
              style: const TextStyle(color: Color(0xFF87CEEB), fontSize: 24, fontWeight: FontWeight.bold)),
          const CircleAvatar(radius: 25, backgroundImage: AssetImage('assets/images/profile_pic.png')),
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
          return GestureDetector(
            onTap: () {
              // Chuyển sang trang Detail và truyền object movie hiện tại
              Navigator.pushNamed(context, '/details', arguments: movie);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
                          Row(children: [const Icon(Icons.star, color: Colors.amber, size: 20), const SizedBox(width: 6), Text(movie.voteAverage.toStringAsFixed(1), style: const TextStyle(color: Colors.amber, fontSize: 18))]),
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
            onTap: () {
              // Chuyển sang trang Detail và truyền object movie hiện tại
              Navigator.pushNamed(context, '/details', arguments: movie);
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(15), child: CachedNetworkImage(imageUrl: movie.posterUrl, fit: BoxFit.cover))),
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(movie.title, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Row(children: [const Icon(Icons.star, color: Color(0xFFFFAB40), size: 14), const SizedBox(width: 4), Text(movie.voteAverage.toStringAsFixed(1), style: const TextStyle(color: Color(0xFFFFAB40), fontSize: 13))]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
