class Comment {
  final String username;
  final String content;
  final DateTime timestamp;
  final String? imageUrl;
  final String? avatarUrl;

  Comment({
    required this.username, 
    required this.content, 
    required this.timestamp,
    this.imageUrl,
    this.avatarUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Handle populated userId object from backend
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
      username: username,
      content: json['content'] ?? '',
      timestamp: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      imageUrl: json['imageUrl'],
      avatarUrl: avatarUrl,
    );
  }
}
