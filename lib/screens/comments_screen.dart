import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../models/comment.dart';
import '../services/backend_service.dart';
import '../providers/auth_provider.dart';

class CommentsScreen extends StatefulWidget {
  final Movie movie;

  const CommentsScreen({super.key, required this.movie});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadComments();
    setState(() => _isLoading = false);
  }

  Future<void> _loadComments() async {
    try {
      final result = await BackendService.getComments(widget.movie.id);

      if (result['success'] == true) {
        final List<dynamic> commentsData = result['data'] ?? [];
        setState(() {
          _comments = commentsData.map((json) => Comment.fromJson(json)).toList().reversed.toList();
        });
      } else {
        print('Failed to load comments: ${result['message']}');
      }
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final content = _commentController.text.trim();
    final auth = context.read<AuthProvider>();
    final username = auth.currentUser ?? 'User';

    try {
      final result = await BackendService.createComment(
        widget.movie.id,
        content,
      );

      if (result['success'] == true) {
        _commentController.clear();
        FocusScope.of(context).unfocus();
        setState(() {
          _comments.add(Comment(
            username: username,
            content: content,
            timestamp: DateTime.now(),
            avatarUrl: auth.avatarUrl,
          ));
        });
      } else {
        if (result['tokenExpired'] == true) {
          await auth.logout();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to post comment'),
              backgroundColor: const Color(0xFFFF6B00),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection error. Please try again.'),
          backgroundColor: Color(0xFFFF6B00),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Banner phim ở trên cùng
          Stack(
            children: [
              SizedBox(
                height: 220,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: widget.movie.backdropUrl ?? '',
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(color: Colors.blueGrey),
                ),
              ),
              // Gradient Overlay
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
              // Nút Back
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8),
                  child: CircleAvatar(
                    backgroundColor: Colors.black38,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
              // Tiêu đề Forum
              Positioned(
                bottom: 20,
                left: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MOVIE FORUM',
                      style: TextStyle(
                        color: Color(0xFF87CEEB),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      widget.movie.title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Danh sách bình luận
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF87CEEB)))
                : _comments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
          ),

          // Ô nhập bình luận
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text("No comments yet. Be the first!", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar tròn bên cạnh tên
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[800],
            backgroundImage: comment.avatarUrl != null && comment.avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(comment.avatarUrl!)
                : const AssetImage('assets/images/profile_pic.png') as ImageProvider,
            child: (comment.avatarUrl == null || comment.avatarUrl!.isEmpty)
                ? Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      comment.username,
                      style: const TextStyle(color: Color(0xFF87CEEB), fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${comment.timestamp.hour}:${comment.timestamp.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.content,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _commentController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: const Color(0xFFFF6B00),
            child: IconButton(
              icon: Icon(Icons.send, color: Theme.of(context).colorScheme.onSurface, size: 20),
              onPressed: _addComment,
            ),
          ),
        ],
      ),
    );
  }
}
