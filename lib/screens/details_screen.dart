import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/movie.dart';
import '../models/cast.dart';
import '../services/tmdb_service.dart';
import '../services/backend_service.dart';

class DetailsScreen extends StatefulWidget {
  final Movie movie;

  const DetailsScreen({super.key, required this.movie});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool _isExpanded = false;
  List<Cast> _cast = [];
  bool _isLoadingCast = true;
  String? _castError;

  double? _userRating;
  double? _averageRating;
  int _totalRatings = 0;
  bool _isLoadingRating = true;
  bool _ratingUpdated = false;
  YoutubePlayerController? _youtubeController;
  bool _isLoadingTrailer = true;
  String? _trailerError;

  @override
  void initState() {
    super.initState();
    _loadCast();
    _loadTrailer();
    _loadRating();
  }

  Future<void> _loadRating() async {
    try {
      final result = await BackendService.getMovieRating(widget.movie.id);
      if (mounted && result['success'] == true) {
        final data = result['data'];
        setState(() {
          _averageRating = (data['averageScore'] ?? 0).toDouble();
          _totalRatings = data['totalRatings'] ?? 0;
          _userRating = data['userScore']?.toDouble();
          _isLoadingRating = false;
        });
      } else {
        setState(() {
          _averageRating = widget.movie.averageRating;
          _totalRatings = widget.movie.totalRatings ?? 0;
          _isLoadingRating = false;
        });
      }
    } catch (e) {
      print('DetailsScreen._loadRating error: $e');
      if (mounted) setState(() {
        _isLoadingRating = false;
      });
    }
  }

  Future<void> _submitRating(double score) async {
    final result = await BackendService.submitRating(
      widget.movie.id,
      score,
      moviePoster: widget.movie.posterPath,
    );
    if (mounted) {
      if (result['success'] == true) {
        await _loadRating();
        setState(() {
          _userRating = score;
          _ratingUpdated = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit rating'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRatingDialog() {
    double tempRating = _userRating ?? 0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('Rate this movie', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    onPressed: () {
                      setDialogState(() => tempRating = star.toDouble());
                    },
                    icon: Icon(
                      star <= tempRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                  );
                }),
              ),
              Text('${tempRating.toInt()}/5', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: tempRating > 0
                  ? () {
                      Navigator.pop(context);
                      _submitRating(tempRating);
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  Future<void> _loadCast() async {
    try {
      final castList = await TmdbService.getMovieCast(widget.movie.id);
      if (mounted) {
        setState(() {
          _cast = castList;
          _isLoadingCast = false;
          if (castList.isEmpty) _castError = 'No cast information available';
        });
      }
    } catch (e) {
      print('DetailsScreen._loadCast error: $e');
      if (mounted) setState(() {
        _isLoadingCast = false;
        _castError = 'Failed to load cast';
      });
    }
  }

  Future<void> _loadTrailer() async {
    try {
      final trailerKey = await TmdbService.getMovieTrailerKey(widget.movie.id);
      if (mounted) {
        if (trailerKey != null && trailerKey.isNotEmpty) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: trailerKey,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              disableDragSeek: false,
            ),
          );
        }
        setState(() => _isLoadingTrailer = false);
      }
    } catch (e) {
      print('DetailsScreen._loadTrailer error: $e');
      if (mounted) setState(() {
        _isLoadingTrailer = false;
        _trailerError = 'Failed to load trailer';
      });
    }
  }

  void _showActorDetails(Cast actor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (bottomSheetContext) => Container(
        margin: const EdgeInsets.only(top: 80),
        decoration: const BoxDecoration(
          color: Color(0xFF1B263B),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: TmdbService.getActorDetails(actor.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 300,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHandle(bottomSheetContext),
                    const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF87CEEB)))),
                  ],
                ),
              );
            }
            final details = snapshot.data;
            final biography = (details?['biography'] as String?)?.isNotEmpty == true 
                ? details!['biography'] 
                : "No biography available for this actor.";

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHandle(bottomSheetContext),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 40, backgroundColor: Colors.white10, backgroundImage: CachedNetworkImageProvider(actor.profileUrl)),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(actor.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                                Text("as ${actor.character}", style: const TextStyle(color: Color(0xFF87CEEB), fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("Biography", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(biography, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15, height: 1.5), textAlign: TextAlign.justify),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHandle(BuildContext ctx) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 22),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        const Expanded(child: Center(child: Opacity(opacity: 0.1, child: SizedBox(width: 40, child: Divider(thickness: 4, color: Colors.white))))),
        const SizedBox(width: 48),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final genreNames = TmdbService.getGenreNames(widget.movie.genreIds);
    
    return PopScope(
      canPop: !_ratingUpdated,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _ratingUpdated) {
          Navigator.pop(context, {
            'updatedRating': true,
            'movieId': widget.movie.id,
            'averageRating': _averageRating,
            'totalRatings': _totalRatings,
          });
        }
      },
      child: YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _youtubeController ?? YoutubePlayerController(initialVideoId: ''),
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300, pinned: true, backgroundColor: const Color(0xFF0D1B2A),
                flexibleSpace: FlexibleSpaceBar(background: CachedNetworkImage(imageUrl: widget.movie.backdropUrl, fit: BoxFit.cover)),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.movie.title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 30, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        GestureDetector(
                          onTap: _showRatingDialog,
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 22),
                              const SizedBox(width: 6),
                              _isLoadingRating
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                  : Text(
                                      _averageRating != null && _averageRating! > 0
                                          ? _averageRating!.toStringAsFixed(1)
                                          : '0.0',
                                      style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                              if (_totalRatings > 0) ...[
                                const SizedBox(width: 4),
                                Text('($_totalRatings)', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (_userRating != null) ...[
                          const Icon(Icons.person, color: Color(0xFF87CEEB), size: 18),
                          const SizedBox(width: 4),
                          Text('Yours: ${_userRating!.toStringAsFixed(1)}', style: const TextStyle(color: Color(0xFF87CEEB), fontSize: 16)),
                          const SizedBox(width: 16),
                        ],
                        const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(widget.movie.releaseDate, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
                      ]),
                      const SizedBox(height: 20),
                      Wrap(spacing: 8, runSpacing: 8, children: genreNames.map((name) => _buildGenreChip(name)).toList()),
                      const SizedBox(height: 30),
                      const Text('Overview', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildOverview(),
                      const SizedBox(height: 35),
                      const Text('Cast', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      _isLoadingCast
                          ? const Center(child: CircularProgressIndicator())
                          : _castError != null
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(_castError!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ),
                                )
                              : _buildCastList(),
                      const SizedBox(height: 35),
                      const Text('Trailer', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      _isLoadingTrailer
                          ? const Center(child: CircularProgressIndicator())
                          : _trailerError != null
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(_trailerError!, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ),
                                )
                              : _youtubeController != null 
                                  ? Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)), child: ClipRRect(borderRadius: BorderRadius.circular(15), child: player))
                                  : const Text("Trailer not available", style: TextStyle(color: Colors.white54)),
                      
                      const SizedBox(height: 40),
                      
                      // Nút Comment - Đã gắn sự kiện chuyển hướng
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/comments', arguments: widget.movie);
                          },
                          icon: const Icon(Icons.comment, color: Colors.white),
                          label: const Text(
                            'Write a Comment',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    ),
    );
  }

  Widget _buildOverview() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.movie.overview, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, height: 1.6), maxLines: _isExpanded ? null : 4, textAlign: TextAlign.justify),
      GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Text(_isExpanded ? 'Read less' : 'Read more', style: const TextStyle(color: Color(0xFF87CEEB), fontWeight: FontWeight.bold)),
      )
    ]);
  }

  Widget _buildCastList() {
    return SizedBox(height: 160, child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _cast.length,
      itemBuilder: (context, index) {
        final actor = _cast[index];
        return GestureDetector(
          onTap: () => _showActorDetails(actor),
          child: Container(width: 100, margin: const EdgeInsets.only(right: 16), child: Column(children: [
            CircleAvatar(radius: 40, backgroundImage: CachedNetworkImageProvider(actor.profileUrl)),
            const SizedBox(height: 10),
            Text(actor.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12), textAlign: TextAlign.center, maxLines: 2),
          ])),
        );
      },
    ));
  }

  Widget _buildGenreChip(String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)));
  }
}
