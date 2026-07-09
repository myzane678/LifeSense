class NewsItem {
  const NewsItem({
    required this.title,
    required this.summary,
    required this.link,
    required this.source,
    required this.publishedAt,
  });

  final String title;
  final String summary;
  final String link;
  final String source;
  final DateTime publishedAt;
}
