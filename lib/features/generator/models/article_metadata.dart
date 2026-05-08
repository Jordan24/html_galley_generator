class ArticleMetadata {
  final String title;
  final String author; // Last name, uppercase (e.g. COLLINS)
  final String authorFullName; // Full name (e.g. Lauren Collins)
  final String authorFirstName;
  final String authorLastName;
  final String authorOrcid; // e.g. 0000-0002-2168-3352
  final String authorAffiliation; // e.g. University of Colorado Boulder
  final String authorBio; // Full bio paragraph HTML
  final String volume;
  final String issue;
  final String articleId; // OJS submission/article ID (e.g. 113)
  final String submissionId; // Same as articleId typically
  final String issueViewId; // OJS issue view ID (e.g. 15)
  final String pdfGalleyId; // OJS galley/file ID for the PDF download (e.g. 191)
  final String publishedDate; // ISO8601 e.g. 2025-10-31
  final String issuedDate; // ISO8601 e.g. 2025-10-31
  final String publishedDateMonYYYY; // e.g. Oct. 2025
  final String publishYear; // e.g. 2025
  final String submittedDate; // ISO8601 e.g. 2024-12-28
  final String modifiedDate; // ISO8601 e.g. 2025-11-10
  final String keywords; // Comma-separated keywords
  final String articleBody; // Full article body HTML content (includes abstract, keywords, bib, footnotes)
  final String titleMain; // Typically same as journalName or similar
  final String articleAbstract; // Plain text abstract for meta tags

  const ArticleMetadata({
    this.title = '',
    this.author = '',
    this.authorFullName = '',
    this.authorFirstName = '',
    this.authorLastName = '',
    this.authorOrcid = '',
    this.authorAffiliation = '',
    this.authorBio = '',
    this.volume = '',
    this.issue = '',
    this.articleId = '',
    this.submissionId = '',
    this.issueViewId = '',
    this.pdfGalleyId = '',
    this.publishedDate = '',
    this.issuedDate = '',
    this.publishedDateMonYYYY = '',
    this.publishYear = '',
    this.submittedDate = '',
    this.modifiedDate = '',
    this.keywords = '',
    this.articleBody = '',
    this.titleMain = '',
    this.articleAbstract = '',
  });

  ArticleMetadata copyWith({
    String? title,
    String? author,
    String? authorFullName,
    String? authorFirstName,
    String? authorLastName,
    String? authorOrcid,
    String? authorAffiliation,
    String? authorBio,
    String? volume,
    String? issue,
    String? articleId,
    String? submissionId,
    String? issueViewId,
    String? pdfGalleyId,
    String? publishedDate,
    String? issuedDate,
    String? publishedDateMonYYYY,
    String? publishYear,
    String? submittedDate,
    String? modifiedDate,
    String? keywords,
    String? articleBody,
    String? titleMain,
    String? articleAbstract,
  }) {
    return ArticleMetadata(
      title: title ?? this.title,
      author: author ?? this.author,
      authorFullName: authorFullName ?? this.authorFullName,
      authorFirstName: authorFirstName ?? this.authorFirstName,
      authorLastName: authorLastName ?? this.authorLastName,
      authorOrcid: authorOrcid ?? this.authorOrcid,
      authorAffiliation: authorAffiliation ?? this.authorAffiliation,
      authorBio: authorBio ?? this.authorBio,
      volume: volume ?? this.volume,
      issue: issue ?? this.issue,
      articleId: articleId ?? this.articleId,
      submissionId: submissionId ?? this.submissionId,
      issueViewId: issueViewId ?? this.issueViewId,
      pdfGalleyId: pdfGalleyId ?? this.pdfGalleyId,
      publishedDate: publishedDate ?? this.publishedDate,
      issuedDate: issuedDate ?? this.issuedDate,
      publishedDateMonYYYY: publishedDateMonYYYY ?? this.publishedDateMonYYYY,
      publishYear: publishYear ?? this.publishYear,
      submittedDate: submittedDate ?? this.submittedDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      keywords: keywords ?? this.keywords,
      articleBody: articleBody ?? this.articleBody,
      titleMain: titleMain ?? this.titleMain,
      articleAbstract: articleAbstract ?? this.articleAbstract,
    );
  }
}
