import '../config/api_config.dart';

class Comment {
  final String? id;
  final String username;
  final String content;
  final DateTime timestamp;
  final String? imageUrl;
  final String? avatarUrl;
  final String? parentCommentId;
  final List<String> likes;
  final bool isDeleted;

  Comment({
    this.id,
    required this.username,
    required this.content,
    required this.timestamp,
    this.imageUrl,
    this.avatarUrl,
    this.parentCommentId,
    this.likes = const [],
    this.isDeleted = false,
  });

  bool get isParent => parentCommentId == null;
  int get likesCount => likes.length;

  bool isLikedBy(String userId) => likes.contains(userId);

  Comment copyWith({List<String>? likes}) {
    return Comment(
      id: id,
      username: username,
      content: content,
      timestamp: timestamp,
      imageUrl: imageUrl,
      avatarUrl: avatarUrl,
      parentCommentId: parentCommentId,
      likes: likes ?? this.likes,
      isDeleted: isDeleted,
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    String username = 'Unknown';
    String? avatarUrl;
    final userId = json['userId'];
    if (userId is Map<String, dynamic>) {
      username = userId['username'] ?? 'Unknown';
      final raw = userId['avatar_url']?.toString();
      avatarUrl = (raw != null && !raw.contains('thenounproject.com'))
          ? ApiConfig.normalizeUrl(raw) : null;
    } else if (json['username'] != null) {
      username = json['username'];
    }

    List<String> likes = [];
    if (json['likes'] != null && json['likes'] is List) {
      likes = (json['likes'] as List).map((e) => e.toString()).toList();
    }

    return Comment(
      id: json['_id']?.toString(),
      username: username,
      content: json['content'] ?? '',
      timestamp: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      imageUrl: ApiConfig.normalizeUrl(json['imageUrl']?.toString()),
      avatarUrl: avatarUrl,
      parentCommentId: json['parentCommentId']?.toString(),
      likes: likes,
      isDeleted: json['isDeleted'] == true,
    );
  }
}
