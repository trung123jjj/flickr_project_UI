class Comment {
  final String? id;
  final String username;
  final String content;
  final DateTime timestamp;
  final String? imageUrl;
  final String? avatarUrl;
  final String? parentCommentId;

  Comment({
    this.id,
    required this.username,
    required this.content,
    required this.timestamp,
    this.imageUrl,
    this.avatarUrl,
    this.parentCommentId,
  });

  bool get isParent => parentCommentId == null;

  factory Comment.fromJson(Map<String, dynamic> json) {
    String username = 'Unknown';
    String? avatarUrl;
    final userId = json['userId'];
    if (userId is Map<String, dynamic>) {
      username = userId['username'] ?? 'Unknown';
      avatarUrl = userId['avatar_url'];
    } else if (json['username'] != null) {
      username = json['username'];
    }

    return Comment(
      id: json['_id']?.toString(),
      username: username,
      content: json['content'] ?? '',
      timestamp: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      imageUrl: json['imageUrl'],
      avatarUrl: avatarUrl,
      parentCommentId: json['parentCommentId']?.toString(),
    );
  }
}
