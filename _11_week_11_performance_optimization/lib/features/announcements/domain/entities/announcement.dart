/// Entitas pengumuman kampus (murni Dart, tanpa dependensi Flutter).
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.publishedAt,
  });

  final int id;
  final String title;
  final String body;
  final String category;
  final String imageUrl;
  final String thumbnailUrl;
  final DateTime publishedAt;

  Announcement copyWith({
    String? title,
    String? body,
    String? category,
    String? imageUrl,
    String? thumbnailUrl,
    DateTime? publishedAt,
  }) {
    return Announcement(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category,
    'imageUrl': imageUrl,
    'thumbnailUrl': thumbnailUrl,
    'publishedAt': publishedAt.toIso8601String(),
  };

  factory Announcement.fromJson(Map<String, Object?> json) {
    return Announcement(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? 'Umum',
      imageUrl: json['imageUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Announcement && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
