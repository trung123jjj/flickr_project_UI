import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/movie.dart';
import '../models/cast.dart';
import '../services/tmdb_service.dart';

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
  
  YoutubePlayerController? _youtubeController;
  bool _isLoadingTrailer = true;

  @override
  void initState() {
    super.initState();
    _loadCast();
    _loadTrailer();
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  Future<void> _loadCast() async {
    final castList = await TmdbService.getMovieCast(widget.movie.id);
    if (mounted) {
      setState(() {
        _cast = castList;
        _isLoadingCast = false;
      });
    }
  }

  Future<void> _loadTrailer() async {
    final trailerKey = await TmdbService.getMovieTrailerKey(widget.movie.id);
    if (mounted) {
      if (trailerKey != null && trailerKey.isNotEmpty) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: trailerKey,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            disableDragSeek: false,
            loop: false,
            isLive: false,
            forceHD: false,
            enableCaption: true,
          ),
        );
      }
      setState(() => _isLoadingTrailer = false);
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
                                Text(actor.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                      child: Text(biography, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5), textAlign: TextAlign.justify),
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
    
    // Nếu có video trailer, sử dụng YoutubePlayerBuilder để tối ưu hóa trình phát
    if (_youtubeController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: const Color(0xFF87CEEB),
        ),
        builder: (context, player) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D1B2A),
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 350, pinned: true, backgroundColor: const Color(0xFF0D1B2A),
                  flexibleSpace: FlexibleSpaceBar(background: CachedNetworkImage(imageUrl: widget.movie.backdropUrl, fit: BoxFit.cover)),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.movie.title, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(children: [const Icon(Icons.star, color: Colors.amber, size: 22), const SizedBox(width: 6), Text(widget.movie.voteAverage.toStringAsFixed(1), style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(width: 24), const Icon(Icons.calendar_today, color: Colors.white70, size: 18), const SizedBox(width: 8), Text(widget.movie.releaseDate, style: const TextStyle(color: Colors.white70, fontSize: 16))]),
                        const SizedBox(height: 20),
                        Wrap(spacing: 8, runSpacing: 8, children: genreNames.map((name) => _buildGenreChip(name)).toList()),
                        const SizedBox(height: 30),
                        const Text('Overview', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.movie.overview, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6), maxLines: _isExpanded ? null : 4, overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis, textAlign: TextAlign.justify), const SizedBox(height: 5), GestureDetector(onTap: () => setState(() => _isExpanded = !_isExpanded), child: Text(_isExpanded ? 'Read less' : 'Read more', style: const TextStyle(color: Color(0xFF87CEEB), fontWeight: FontWeight.bold, fontSize: 16)))]),
                        const SizedBox(height: 35),
                        const Text('Cast', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _isLoadingCast ? const Center(child: CircularProgressIndicator(color: Color(0xFF87CEEB))) : _buildCastList(),
                        const SizedBox(height: 35),
                        const Text('Trailer', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
                          child: ClipRRect(borderRadius: BorderRadius.circular(15), child: player),
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Trường hợp đang tải hoặc không có trailer
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350, pinned: true, backgroundColor: const Color(0xFF0D1B2A),
            flexibleSpace: FlexibleSpaceBar(background: CachedNetworkImage(imageUrl: widget.movie.backdropUrl, fit: BoxFit.cover)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.movie.title, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [const Icon(Icons.star, color: Colors.amber, size: 22), const SizedBox(width: 6), Text(widget.movie.voteAverage.toStringAsFixed(1), style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(width: 24), const Icon(Icons.calendar_today, color: Colors.white70, size: 18), const SizedBox(width: 8), Text(widget.movie.releaseDate, style: const TextStyle(color: Colors.white70, fontSize: 16))]),
                  const SizedBox(height: 20),
                  Wrap(spacing: 8, runSpacing: 8, children: genreNames.map((name) => _buildGenreChip(name)).toList()),
                  const SizedBox(height: 30),
                  const Text('Overview', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.movie.overview, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6), maxLines: _isExpanded ? null : 4, overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis, textAlign: TextAlign.justify), const SizedBox(height: 5), GestureDetector(onTap: () => setState(() => _isExpanded = !_isExpanded), child: Text(_isExpanded ? 'Read less' : 'Read more', style: const TextStyle(color: Color(0xFF87CEEB), fontWeight: FontWeight.bold, fontSize: 16)))]),
                  const SizedBox(height: 35),
                  const Text('Cast', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _isLoadingCast ? const Center(child: CircularProgressIndicator(color: Color(0xFF87CEEB))) : _buildCastList(),
                  const SizedBox(height: 35),
                  const Text('Trailer', style: TextStyle(color: Color(0xFF87CEEB), fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _isLoadingTrailer 
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF87CEEB)))
                      : const Text("Trailer not available", style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCastList() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _cast.length,
        itemBuilder: (context, index) {
          final actor = _cast[index];
          return GestureDetector(
            onTap: () => _showActorDetails(actor),
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  CircleAvatar(radius: 40, backgroundColor: Colors.white10, backgroundImage: CachedNetworkImageProvider(actor.profileUrl)),
                  const SizedBox(height: 10),
                  Text(actor.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(actor.character, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenreChip(String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)), child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)));
  }
}
