/// Holds the metadata fields extracted from a PDF and displayed in the form.
class ArticleMetadata {
  final String title;
  final String author;
  final String volume;
  final String issue;
  final String articleId;

  const ArticleMetadata({
    this.title = '',
    this.author = '',
    this.volume = '',
    this.issue = '',
    this.articleId = '',
  });

  ArticleMetadata copyWith({
    String? title,
    String? author,
    String? volume,
    String? issue,
    String? articleId,
  }) {
    return ArticleMetadata(
      title: title ?? this.title,
      author: author ?? this.author,
      volume: volume ?? this.volume,
      issue: issue ?? this.issue,
      articleId: articleId ?? this.articleId,
    );
  }
}
