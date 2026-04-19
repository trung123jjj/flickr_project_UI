class Genre {
  final int id;
  final String name;
  String? backdropUrl; // Dùng ảnh ngang làm đại diện

  Genre({required this.id, required this.name, this.backdropUrl});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'],
      name: json['name'],
    );
  }
}
