class Article {
  final String id;
  final String title;
  final String summary;
  final String? image;
  final String url;
  final String source;
  final String? publishedAt;
  final String? category;
  final String? country;
  final String type; // 'article' or 'ad'

  const Article({
    required this.id,
    required this.title,
    required this.summary,
    this.image,
    required this.url,
    required this.source,
    this.publishedAt,
    this.category,
    this.country,
    this.type = 'article',
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      image: json['image'] as String?,
      url: json['url'] as String,
      source: json['source'] as String? ?? '',
      publishedAt: json['publishedAt'] as String?,
      category: json['category'] as String?,
      country: json['country'] as String?,
      type: json['type'] as String? ?? 'article',
    );
  }

  Article copyWith({String? type}) {
    return Article(
      id: id,
      title: title,
      summary: summary,
      image: image,
      url: url,
      source: source,
      publishedAt: publishedAt,
      category: category,
      country: country,
      type: type ?? this.type,
    );
  }
}
