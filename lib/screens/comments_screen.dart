import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/movie.dart';
import '../models/comment.dart';
import '../services/backend_service.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class _DisplayItem {
  final Comment comment;
  final String? parentContent;
  final String? parentUsername;
  final bool isParentDeleted;
  const _DisplayItem(this.comment, this.parentContent, [this.parentUsername, this.isParentDeleted = false]);
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
  List<_DisplayItem> _displayItems = [];
  bool _needsRebuild = true;
  IO.Socket? _socket;
  final Set<String?> _highlightedComments = {};
  final ScrollController _scrollController = ScrollController();
  bool _socketConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _connectSocket();
      _startPollingFallback();
    });
  }

  @override
  void dispose() {
    _socket?.emit("leaveMovie", widget.movie.id.toString());
    _socket?.disconnect();
    _socket?.dispose();
    _pollTimer?.cancel();
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Timer? _pollTimer;

  void _startPollingFallback() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_socketConnected) {
        print('[Poll] Socket not connected, polling...');
        _loadComments();
      }
    });
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _connectSocket() {
    try {
      _socket = IO.io(
        ApiConfig.backendBaseUrl,
        IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .build(),
      );

      _socket?.onConnect((_) {
        print('[Socket] Connected: ${_socket?.id}');
        _socketConnected = true;
        _socket?.emit("joinMovie", widget.movie.id.toString());
      });

      _socket?.onConnectError((err) {
        print('[Socket] Connect error: $err');
        _socketConnected = false;
      });

      _socket?.onError((err) {
        print('[Socket] Error: $err');
        _socketConnected = false;
      });

      _socket?.on('reconnect', (_) {
        print('[Socket] Reconnected');
        _socketConnected = true;
        _socket?.emit("joinMovie", widget.movie.id.toString());
      });

      _socket?.on("newComment", (data) {
        if (data is Map<String, dynamic>) {
          final comment = Comment.fromJson(data);
          if (mounted) {
            setState(() {
              final exists = _comments.any((c) => c.id == comment.id);
              if (!exists) {
                _comments.add(comment);
                _highlightedComments.add(comment.id);
                _markNeedsRebuild();
              }
            });
            _scrollToLatest();
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) setState(() => _highlightedComments.remove(comment.id));
            });
          }
        }
      });

      _socket?.on("commentUpdated", (data) {
        if (data is Map<String, dynamic>) {
          final updated = Comment.fromJson(data);
          if (mounted) {
            setState(() {
              final idx = _comments.indexWhere((c) => c.id == updated.id);
              if (idx != -1) _comments[idx] = updated;
              _markNeedsRebuild();
            });
          }
        }
      });

      _socket?.on("commentDeleted", (data) {
        if (data is Map<String, dynamic>) {
          final deleted = Comment.fromJson(data);
          if (mounted) {
            setState(() {
              final idx = _comments.indexWhere((c) => c.id == deleted.id);
              if (idx != -1) {
                _comments[idx] = Comment(
                  id: deleted.id,
                  username: deleted.username,
                  content: '',
                  timestamp: deleted.timestamp,
                  avatarUrl: deleted.avatarUrl,
                  parentCommentId: deleted.parentCommentId,
                  isDeleted: true,
                );
              }
              _markNeedsRebuild();
            });
          }
        }
      });

      _socket?.onDisconnect((reason) => print('[Socket] Disconnected: $reason'));
    } catch (e) {
      print('[Socket] Error: $e');
    }
  }

  void _rebuildDisplayList() {
    final Map<String, Comment> parentMap = {};
    for (final c in _comments) {
      if (c.id != null) parentMap[c.id!] = c;
    }
    final sorted = List<Comment>.from(_comments)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _displayItems = sorted.map((c) {
      final parent = c.parentCommentId != null ? parentMap[c.parentCommentId] : null;
      return _DisplayItem(c, parent?.content, parent?.username, parent?.isDeleted ?? false);
    }).toList();
    _needsRebuild = false;
  }

  void _markNeedsRebuild() {
    _needsRebuild = true;
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
          _markNeedsRebuild();
        });
      } else {
        print('Failed to load comments: ${result['message']}');
      }
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  void _showReplyMenu(Comment comment) {
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.userId ?? '';
    final isLiked = comment.isLikedBy(currentUserId);
    final isOwn = comment.username == auth.currentUser;

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
                leading: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: const Color(0xFFE53935),
                ),
                title: Text(
                  isLiked ? 'Unlike' : 'Like',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text('@${comment.username}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleLike(comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFFE53935)),
                title: const Text('Reply', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('@${comment.username}'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyingTo = comment);
                },
              ),
              if (isOwn)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
                  title: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFE53935)),
                  ),
                  subtitle: Text('@${comment.username}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(comment);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleLike(Comment comment) async {
    if (comment.id == null) return;
    final result = await BackendService.toggleLikeComment(comment.id!);
    if (result['success'] == true) {
      final data = result['data'];
      if (data is Map<String, dynamic>) {
        final updated = Comment.fromJson(data);
        setState(() {
          final idx = _comments.indexWhere((c) => c.id == comment.id);
          if (idx != -1) {
            _comments[idx] = updated;
          }
          _markNeedsRebuild();
        });
      }
    }
  }

  void _confirmDelete(Comment comment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteComment(comment);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(Comment comment) async {
    if (comment.id == null) return;
    final result = await BackendService.deleteComment(comment.id!);
    if (result['success'] == true) {
      setState(() {
        final idx = _comments.indexWhere((c) => c.id == comment.id);
        if (idx != -1) {
          _comments[idx] = Comment(
            id: comment.id,
            username: comment.username,
            content: '',
            timestamp: comment.timestamp,
            avatarUrl: comment.avatarUrl,
            parentCommentId: comment.parentCommentId,
            isDeleted: true,
          );
        }
        _markNeedsRebuild();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete comment'),
            backgroundColor: const Color(0xFFFF6B00),
          ),
        );
      }
    }
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
        FocusScope.of(context).unfocus();
        _highlightedComments.add(newComment.id);
        setState(() {
          _replyingTo = null;
          _selectedImage = null;
          _comments.add(newComment);
          _markNeedsRebuild();
        });
        _scrollToLatest();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _highlightedComments.remove(newComment.id));
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
    if (_needsRebuild) _rebuildDisplayList();
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
                      'MOVIE CHAT SECTION',
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
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _displayItems.length,
                        itemBuilder: (context, index) {
                          final item = _displayItems[index];
                          return _buildCommentItem(item.comment, !item.comment.isParent, item.parentContent, item.parentUsername, isParentDeleted: item.isParentDeleted);
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

  Widget _buildCommentItem(Comment comment, bool isReply, String? parentContent, String? parentUsername, {bool isParentDeleted = false}) {
    final auth = context.read<AuthProvider>();
    final isMe = comment.username == auth.currentUser;
    final displayName = isMe ? 'You' : comment.username;

    final bubbleColor = isMe
        ? const Color(0xFFE53935)
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
      final hasAvatar = comment.avatarUrl != null && comment.avatarUrl!.isNotEmpty;
      return Padding(
        padding: EdgeInsets.only(left: padLeft, right: padRight),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[800],
          child: hasAvatar
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: comment.avatarUrl!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.person, size: 16, color: Colors.white54),
                    placeholder: (_, __) => const Icon(Icons.person, size: 16, color: Colors.white54),
                  ),
                )
              : const Icon(Icons.person, size: 16, color: Colors.white54),
        ),
      );
    }

    final isHighlighted = _highlightedComments.contains(comment.id);

    Widget commentWidget = GestureDetector(
      onLongPress: comment.isDeleted ? null : () => _showReplyMenu(comment),
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
                                  text: isParentDeleted
                                      ? ': comment removed'
                                      : ': ${parentContent.length > 50 ? '${parentContent.substring(0, 50)}...' : parentContent}',
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
                      comment.isDeleted ? '[comment removed]' : comment.content,
                      style: TextStyle(
                        color: comment.isDeleted ? timeColor : textColor,
                        fontSize: 15,
                        height: 1.4,
                        fontStyle: comment.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeText,
                          style: TextStyle(color: timeColor, fontSize: 11),
                        ),
                        if (comment.likesCount > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.favorite,
                            size: 12,
                            color: const Color(0xFFF48FB1),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${comment.likesCount}',
                            style: TextStyle(
                              color: const Color(0xFFF48FB1),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
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

    if (isHighlighted) {
      commentWidget = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.scale(scale: value, child: child),
          );
        },
        child: commentWidget,
      );
    }

    return commentWidget;
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
                backgroundColor: const Color(0xFFE53935),
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
