/// Holds the metadata fields extracted from a PDF and displayed in the form.
class ArticleMetadata {
  final String title;
  final String author; // Last name, uppercase (e.g. COLLINS)
  final String authorFullName; // Full name (e.g. Lauren Collins)
  final String authorOrcid; // e.g. 0000-0002-2168-3352
  final String authorAffiliation; // e.g. University of Colorado Boulder
  final String authorBio; // Full bio paragraph HTML
  final String volume;
  final String issue;
  final String articleId; // OJS submission/article ID (e.g. 113)
  final String submissionId; // Same as articleId typically
  final String publicationId; // OJS publication ID (e.g. 107)
  final String issueViewId; // OJS issue view ID (e.g. 15)
  final String pdfGalleyId; // OJS galley/file ID for the PDF download (e.g. 191)
  final String publishedDate; // ISO8601 e.g. 2025-10-31
  final String submittedDate; // ISO8601 e.g. 2024-12-28
  final String modifiedDate; // ISO8601 e.g. 2025-11-10
  final String abstract_; // Full abstract text (plain text or HTML)
  final String keywords; // Comma-separated keywords
  final String articleBodyHtml; // Full article body HTML content

  const ArticleMetadata({
    this.title = '',
    this.author = '',
    this.authorFullName = '',
    this.authorOrcid = '',
    this.authorAffiliation = '',
    this.authorBio = '',
    this.volume = '',
    this.issue = '',
    this.articleId = '',
    this.submissionId = '',
    this.publicationId = '',
    this.issueViewId = '',
    this.pdfGalleyId = '',
    this.publishedDate = '',
    this.submittedDate = '',
    this.modifiedDate = '',
    this.abstract_ = '',
    this.keywords = '',
    this.articleBodyHtml = '',
  });

  ArticleMetadata copyWith({
    String? title,
    String? author,
    String? authorFullName,
    String? authorOrcid,
    String? authorAffiliation,
    String? authorBio,
    String? volume,
    String? issue,
    String? articleId,
    String? submissionId,
    String? publicationId,
    String? issueViewId,
    String? pdfGalleyId,
    String? publishedDate,
    String? submittedDate,
    String? modifiedDate,
    String? abstract_,
    String? keywords,
    String? articleBodyHtml,
  }) {
    return ArticleMetadata(
      title: title ?? this.title,
      author: author ?? this.author,
      authorFullName: authorFullName ?? this.authorFullName,
      authorOrcid: authorOrcid ?? this.authorOrcid,
      authorAffiliation: authorAffiliation ?? this.authorAffiliation,
      authorBio: authorBio ?? this.authorBio,
      volume: volume ?? this.volume,
      issue: issue ?? this.issue,
      articleId: articleId ?? this.articleId,
      submissionId: submissionId ?? this.submissionId,
      publicationId: publicationId ?? this.publicationId,
      issueViewId: issueViewId ?? this.issueViewId,
      pdfGalleyId: pdfGalleyId ?? this.pdfGalleyId,
      publishedDate: publishedDate ?? this.publishedDate,
      submittedDate: submittedDate ?? this.submittedDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      abstract_: abstract_ ?? this.abstract_,
      keywords: keywords ?? this.keywords,
      articleBodyHtml: articleBodyHtml ?? this.articleBodyHtml,
    );
  }
}
