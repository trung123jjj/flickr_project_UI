class Comment {
  final String username;
  final String content;
  final DateTime timestamp;
  final String? imageUrl;

  Comment({
    required this.username, 
    required this.content, 
    required this.timestamp,
    this.imageUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Handle populated userId object from backend
    String username = 'Unknown';
    final userId = json['userId'];
    if (userId is Map<String, dynamic>) {
      username = userId['username'] ?? 'Unknown';
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
    );
  }
}
