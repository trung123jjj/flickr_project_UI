class Cast {
  final int id;
  final String name;
  final String character;
  final String? profilePath;

  Cast({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
  });

  factory Cast.fromJson(Map<String, dynamic> json) {
    return Cast(
      id: json['id'],
      name: json['name'] ?? '',
      character: json['character'] ?? '',
      profilePath: json['profile_path'],
    );
  }

  String get profileUrl => profilePath != null 
    ? 'https://image.tmdb.org/t/p/w200$profilePath' 
    : 'https://www.pngitem.com/pimgs/m/146-1468479_my-profile-icon-blank-profile-picture-circle-hd.png';
}
