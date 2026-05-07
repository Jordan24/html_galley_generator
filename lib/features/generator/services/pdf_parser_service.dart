import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/article_metadata.dart';

/// Parses a PDF file and extracts [ArticleMetadata] from its content.
class PdfParserService {
  /// Returns an [ArticleMetadata] populated from the given [file].
  /// Throws if the file cannot be read or parsed.
  Future<ArticleMetadata> parse(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    try {
      final extractedText = PdfTextExtractor(document).extractText();

      final title = _extractTitle(document);
      final author = _extractAuthor(document);
      final (volume, issue, articleId) = _extractDoiFields(extractedText);

      return ArticleMetadata(
        title: title,
        author: author,
        volume: volume,
        issue: issue,
        articleId: articleId,
      );
    } finally {
      document.dispose();
    }
  }

  String _extractTitle(PdfDocument document) {
    final info = document.documentInformation;
    return info.title.isNotEmpty ? info.title : '';
  }

  String _extractAuthor(PdfDocument document) {
    final info = document.documentInformation;
    if (info.author.isEmpty) return '';
    return info.author.split(' ').last.toUpperCase();
  }

  /// Extracts volume, issue, and article ID from a DOI string embedded in the
  /// text (e.g., `10.25615/ta.v7i1.113`).
  (String volume, String issue, String articleId) _extractDoiFields(
    String text,
  ) {
    final doiRegex = RegExp(
      r'10\.\d{4,9}/[a-zA-Z0-9.-]+v(\d+)i(\d+)\.(\d+)',
    );
    final match = doiRegex.firstMatch(text);
    if (match == null) return ('', '', '');
    return (
      match.group(1) ?? '',
      match.group(2) ?? '',
      match.group(3) ?? '',
    );
  }
}
