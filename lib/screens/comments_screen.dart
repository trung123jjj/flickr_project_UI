import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/movie.dart';
import '../models/comment.dart';
import '../services/backend_service.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class _DisplayItem {
  final Comment comment;
  final String? parentContent;
  final String? parentUsername;
  const _DisplayItem(this.comment, this.parentContent, [this.parentUsername]);
}

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
  File? _selectedImage;
  bool _isUploadingImage = false;
  Comment? _replyingTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  List<_DisplayItem> _buildDisplayList() {
    final parents = _comments.where((c) => c.isParent).toList();
    final items = <_DisplayItem>[];
    for (final parent in parents) {
      items.add(_DisplayItem(parent, null));
      final replies = _comments
          .where((c) => c.parentCommentId == parent.id)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (final reply in replies) {
        items.add(_DisplayItem(reply, parent.content, parent.username));
      }
    }
    return items;
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _removeSelectedImage() {
    setState(() => _selectedImage = null);
  }

  Future<String?> _uploadImage(File image) async {
    setState(() => _isUploadingImage = true);
    try {
      final result = await BackendService.uploadCommentImage(image);
      if (result['success'] == true) {
        final data = result['data'];
        if (data is Map) {
          return data['imageUrl']?.toString();
        }
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadComments();
    setState(() => _isLoading = false);
  }

  Future<void> _loadComments() async {
    try {
      final url = '${ApiConfig.backendBaseUrl}/api/comments/${widget.movie.id}';
      print('Fetching comments from: $url');

      final result = await BackendService.getComments(widget.movie.id);
      print('Comment result: success=${result['success']}, data=${result['data']?.runtimeType}, message=${result['message']}');

      if (result['success'] == true) {
        final rawData = result['data'];
        List<dynamic> commentsData = [];
        if (rawData is List) {
          commentsData = rawData;
        } else {
          print('WARNING: data is not a List: ${rawData.runtimeType} -> $rawData');
        }
        print('Comments count: ${commentsData.length}');

        setState(() {
          _comments = commentsData.map((json) {
            try {
              return Comment.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              print('Error parsing comment: $e, json=$json');
              rethrow;
            }
          }).toList().reversed.toList();
        });
      } else {
        print('Failed to load comments: ${result['message']}');
      }
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  void _showReplyMenu(Comment comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFFFF6B00)),
                title: const Text('Reply', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('@${comment.username}'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyingTo = comment);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty && _selectedImage == null) return;

    final content = _commentController.text.trim();
    final auth = context.read<AuthProvider>();
    final username = auth.currentUser ?? 'User';

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
      if (imageUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: Color(0xFFFF6B00),
            ),
          );
        }
        return;
      }
    }

    try {
      final result = await BackendService.createComment(
        widget.movie.id,
        content,
        imageUrl: imageUrl,
        parentCommentId: _replyingTo?.id,
      );

      if (result['success'] == true) {
        final data = result['data'];
        Comment newComment;
        if (data is Map<String, dynamic> && data['_id'] != null) {
          newComment = Comment.fromJson(data);
        } else if (data is Map && data['_id'] != null) {
          newComment = Comment.fromJson(Map<String, dynamic>.from(data));
        } else {
          newComment = Comment(
            username: username,
            content: content,
            timestamp: DateTime.now(),
            avatarUrl: auth.avatarUrl,
            imageUrl: imageUrl,
            parentCommentId: _replyingTo?.id,
          );
        }
        _commentController.clear();
        _removeSelectedImage();
        _cancelReply();
        FocusScope.of(context).unfocus();
        setState(() => _comments.add(newComment));
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
              Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
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
              Positioned(
                bottom: 20,
                left: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MOVIE FORUM',
                      style: TextStyle(
                        color: Color(0xFFE53935),
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

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE53935)))
                : _comments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _buildDisplayList().length,
                        itemBuilder: (context, index) {
                          final item = _buildDisplayList()[index];
                          return _buildCommentItem(item.comment, !item.comment.isParent, item.parentContent, item.parentUsername);
                        },
                      ),
          ),

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
          Icon(Icons.forum_outlined, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text("No comments yet. Be the first!", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, bool isReply, String? parentContent, String? parentUsername) {
    final auth = context.read<AuthProvider>();
    final isMe = comment.username == auth.currentUser;
    final displayName = isMe ? 'You' : comment.username;

    final bubbleColor = isMe
        ? const Color(0xFFFF6B00)
        : Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFE8E8E8);

    final textColor = isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final timeColor = isMe ? Colors.white60 : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    final timeText = comment.timestamp.day == DateTime.now().day &&
            comment.timestamp.month == DateTime.now().month &&
            comment.timestamp.year == DateTime.now().year
        ? "${comment.timestamp.hour.toString().padLeft(2, '0')}:${comment.timestamp.minute.toString().padLeft(2, '0')}"
        : "${comment.timestamp.day.toString().padLeft(2, '0')}/${comment.timestamp.month.toString().padLeft(2, '0')}/${comment.timestamp.year}";

    Widget _avatar(double padLeft, double padRight) {
      return Padding(
        padding: EdgeInsets.only(left: padLeft, right: padRight),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[800],
          backgroundImage: comment.avatarUrl != null && comment.avatarUrl!.isNotEmpty
              ? CachedNetworkImageProvider(comment.avatarUrl!)
              : null,
          child: (comment.avatarUrl == null || comment.avatarUrl!.isEmpty)
              ? Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showReplyMenu(comment),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 6,
          left: isReply ? 48.0 : 8.0,
          right: 8,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) _avatar(0, 8),
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
                    bottomRight: isMe ? Radius.zero : const Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (isReply)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            children: [
                              TextSpan(text: 'reply to ${parentUsername ?? comment.username}'),
                              if (parentContent != null)
                                TextSpan(
                                  text: ': ${parentContent.length > 50 ? '${parentContent.substring(0, 50)}...' : parentContent}',
                                ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : const Color(0xFFE53935),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      comment.content,
                      style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                    ),
                    if (comment.imageUrl != null && comment.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: comment.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorWidget: (context, url, error) => Container(
                            color: Colors.black12,
                            height: 80,
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.white38)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      timeText,
                      style: TextStyle(color: timeColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) _avatar(8, 0),
          ],
        ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Color(0xFFFF6B00)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to @${_replyingTo!.username}',
                      style: const TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close, size: 18, color: Color(0xFFFF6B00)),
                  ),
                ],
              ),
            ),
          if (_selectedImage != null)
            Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _selectedImage!,
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 0, right: 0,
                  child: GestureDetector(
                    onTap: _removeSelectedImage,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          Row(
            children: [
              GestureDetector(
                onTap: _isUploadingImage ? null : _pickImage,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[800],
                  child: _isUploadingImage
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.image, color: Colors.white70, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: _replyingTo != null ? 'Write a reply...' : 'Add a comment...',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFFFF6B00),
                child: IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).colorScheme.onSurface, size: 20),
                  onPressed: _addComment,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
