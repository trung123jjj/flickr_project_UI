import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import '../services/backend_service.dart';

class GenreMoviesScreen extends StatefulWidget {
  final int genreId;
  final String genreName;

  const GenreMoviesScreen({
    super.key,
    required this.genreId,
    required this.genreName,
  });

  @override
  State<GenreMoviesScreen> createState() => _GenreMoviesScreenState();
}

class _GenreMoviesScreenState extends State<GenreMoviesScreen> {
  List<Movie> _movies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    try {
      final movies = await TmdbService.getMoviesByGenre(widget.genreId);
      if (!mounted) return;

      if (movies.isNotEmpty) {
        final movieIds = movies.map((m) => m.id).toList();
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
            _movies = movies.map((m) {
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
            _isLoading = false;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _movies = movies;
          _isLoading = false;
          if (movies.isEmpty) {
            _error = 'No movies found for this genre.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load movies.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.genreName),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.dark
              : Brightness.light,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _error != null
              ? Center(
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _movies.length,
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: _MovieRow(movie: _movies[index]),
                    );
                  },
                ),
     );
  }

}

class _MovieRow extends StatelessWidget {
  final Movie movie;

  const _MovieRow({required this.movie});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/details', arguments: movie),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: movie.getPosterUrl('w185'), // Dùng ảnh nhỏ hơn cho thumbnail
                  width: 90,
                  height: 135,
                  fit: BoxFit.cover,
                  memCacheWidth: 180, // Tối ưu memory
                  errorWidget: (context, url, error) => Container(
                    width: 90,
                    height: 135,
                    color: Colors.blueGrey,
                    child: const Icon(Icons.movie, color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            movie.averageRating != null
                                ? movie.averageRating!.toStringAsFixed(1)
                                : '0.0',
                            style: const TextStyle(color: Colors.amber, fontSize: 14),
                          ),
                          if (movie.totalRatings != null && movie.totalRatings! > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${movie.totalRatings})',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        movie.overview.isNotEmpty ? movie.overview : 'No overview available.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, height: 1.3),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}


