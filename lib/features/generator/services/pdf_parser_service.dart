import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/article_metadata.dart';

class PdfParserService {
  Future<ArticleMetadata> parse(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final lines = extractor.extractTextLines();
    final fullText = extractor.extractText();

    String title = '';
    String authorFullName = '';
    String abstractText = '';
    String keywords = '';
    String volume = '';
    String issue = '';
    String articleId = '';
    String authorOrcid = '';
    String authorAffiliation = '';
    String authorBio = '';
    List<String> bodyLines = [];
    List<String> referenceLines = [];

    // 1. Fallback to PDF Metadata
    final info = document.documentInformation;
    if (info.title != null && info.title!.isNotEmpty) {
      title = _clean(info.title!);
    }
    if (info.author != null && info.author!.isNotEmpty) {
      authorFullName = _clean(info.author!);
    }

    bool isAbstract = false;
    bool isKeywords = false;
    bool isReferences = false;
    List<String> titleLines = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = _clean(line.text);
      final fontSize = line.fontSize;

      if (text.isEmpty) continue;

      // 2. Title Detection (if not in metadata or needs refinement)
      // Heuristic: Large font (>13pt), near the top (first 20 lines)
      if (fontSize > 13.0 && i < 20) {
        titleLines.add(text);
        continue;
      }

      // If we found title lines and font size dropped, use them as priority over metadata
      if (titleLines.isNotEmpty && fontSize <= 13.0) {
        final extractedTitle = titleLines.join(' ');
        if (extractedTitle.length > title.length) {
          title = extractedTitle;
        }
        titleLines = []; // Reset to avoid re-triggering
      }

      // 3. Author Detection
      // Heuristic: Medium font (11-13pt), after title, near start
      if (authorFullName.isEmpty && title.isNotEmpty && fontSize >= 11.0 && fontSize <= 13.5 && i < 30) {
        if (!text.toLowerCase().contains('volume') && !text.toLowerCase().contains('issue')) {
          authorFullName = text;
        }
      }

      // 4. Volume/Issue from Text/Headers
      if (text.contains('Volume') && text.contains('Issue')) {
        final volMatch = RegExp(r'Volume\s+(\d+)').firstMatch(text);
        final issMatch = RegExp(r'Issue\s+(\d+)').firstMatch(text);
        if (volMatch != null) volume = volMatch.group(1)!;
        if (issMatch != null) issue = issMatch.group(1)!;
      }

      // 5. Article ID from DOI
      if (text.contains('doi.org')) {
        final idMatch = RegExp(r'\.v\d+i\d+\.(\d+)').firstMatch(text);
        if (idMatch != null) articleId = idMatch.group(1)!;
      }

      // 6. Section Detection
      final lowerText = text.toLowerCase();
      if (lowerText == 'abstract') {
        isAbstract = true;
        isKeywords = false;
        isReferences = false;
        continue;
      } else if (lowerText == 'keywords') {
        isKeywords = true;
        isAbstract = false;
        isReferences = false;
        continue;
      } else if (lowerText == 'bibliography' || lowerText == 'references') {
        isReferences = true;
        isAbstract = false;
        isKeywords = false;
        continue;
      }

      // 7. Section Content
      if (isAbstract) {
        abstractText += ' $text';
      } else if (isKeywords) {
        keywords += text;
      } else if (isReferences) {
        referenceLines.add(text);
      } else if (title.isNotEmpty && authorFullName.isNotEmpty && fontSize >= 9.0 && fontSize <= 11.0) {
        // Body content
        if (text.length > 5 && !text.contains('Transnational Asia')) {
          bodyLines.add(text);
        }
      }
    }

    // 8. Bio and Affiliation Extraction (Heuristic)
    if (authorFullName.isNotEmpty) {
      // Search for author name at the end of the document
      final bioRegex = RegExp('${RegExp.escape(authorFullName)}\\s+is\\s+');
      for (int i = lines.length - 1; i >= 0; i--) {
        final line = lines[i];
        if (bioRegex.hasMatch(line.text)) {
          List<String> bioParts = [_clean(line.text)];
          int j = i + 1;
          // Collect lines until a big gap, page number, or bibliography starts
          while (j < lines.length) {
            final nextLine = lines[j];
            final nextText = _clean(nextLine.text);
            if (nextText.isEmpty) break;
            if (nextText.toLowerCase() == 'bibliography' || nextText == 'Bibliography') break;
            if (RegExp(r'^\d+$').hasMatch(nextText)) break; // Page number
            
            bioParts.add(nextText);
            j++;
          }
          authorBio = bioParts.join(' ');
          
          // Affiliation heuristic: Look for 'University', 'Institute', or 'College' in the bio
          final affMatch = RegExp(r'at\s+(the\s+)?([^.]+University[^.]+|[^.]+Institute[^.]+|[^.]+College[^.]+)').firstMatch(authorBio);
          if (affMatch != null) {
            authorAffiliation = affMatch.group(2)!.trim();
          }
          break;
        }
      }
    }

    // 9. ORCID Extraction
    // Search for patterns like:
    // - orcid.org/0000-0002-2168-3352
    // - 0000-0002-2168-3352 (with -, space, or . as separators)
    final orcidPattern = RegExp(r'(\d{4}[-\s\.]\d{4}[-\s\.]\d{4}[-\s\.]\d{3}[0-9X])');
    
    // Check full text
    var match = orcidPattern.firstMatch(fullText);
    
    // Check keywords if not found in text
    if (match == null && info.keywords != null) {
      match = orcidPattern.firstMatch(info.keywords!);
    }

    // Check link annotations if still not found
    if (match == null) {
      for (int i = 0; i < document.pages.count; i++) {
        final page = document.pages[i];
        for (int j = 0; j < page.annotations.count; j++) {
          final annotation = page.annotations[j];
          if (annotation is PdfUriAnnotation) {
            final uriMatch = orcidPattern.firstMatch(annotation.uri);
            if (uriMatch != null) {
              match = uriMatch;
              break;
            }
          }
        }
        if (match != null) break;
      }
    }
    
    // Normalize to 0000-0000-0000-0000 format
    if (match != null) {
      authorOrcid = match.group(1)!.replaceAll(RegExp(r'[\s\.]'), '-');
    }

    document.dispose();

    // Secondary cleaning/stripping
    abstractText = abstractText.replaceFirst('Abstract ', '').trim();
    keywords = keywords.replaceFirst('Keywords ', '').trim();

    return ArticleMetadata(
      title: title,
      author: authorFullName.split(' ').last.toUpperCase(),
      authorFullName: authorFullName,
      abstract_: abstractText,
      keywords: keywords,
      articleBodyHtml: _processBodyLines(bodyLines) + _processReferenceLines(referenceLines),
      authorOrcid: authorOrcid,
      authorAffiliation: authorAffiliation,
      authorBio: authorBio,
      volume: volume.isEmpty ? '7' : volume,
      issue: issue.isEmpty ? '1' : issue,
      articleId: articleId,
      submissionId: articleId,
      publicationId: '', 
      issueViewId: '',   
      pdfGalleyId: '',   
      publishedDate: DateTime.now().toString().split(' ').first,
      submittedDate: DateTime.now().toString().split(' ').first,
      modifiedDate: DateTime.now().toString().split(' ').first,
    );
  }

  String _clean(String text) {
    if (text.isEmpty) return '';
    return text.trim()
      // Unicode replacement character (often shows as bars/question marks)
      .replaceAll('\uFFFD', "'")
      // Single quotes, smart quotes, backticks, and common mis-encodings (CP1252)
      .replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u2032\u2035\u02BC\u02BD\u02C8\u02CA\u02CB\u00B4\u0060\u0090\u0091\u0092]'), "'")
      // Double quotes
      .replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F\u2033\u2036\u0093\u0094\u00AB\u00BB]'), '"')
      // Dashes and hyphens
      .replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'), '-')
      // Ligatures
      .replaceAll('\uFB01', 'fi')
      .replaceAll('\uFB02', 'fl')
      // Spaces and invisible characters
      .replaceAll(RegExp(r'[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\uFEFF]'), ' ')
      // Control characters (except newlines)
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _processBodyLines(List<String> lines) {
    final buffer = StringBuffer();
    bool inParagraph = false;

    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.isEmpty) continue;

      if (!inParagraph) {
        buffer.write('<p>');
        inParagraph = true;
      }

      buffer.write('$text ');

      // End of paragraph heuristic: ends with period and next line starts with capital letter or is far away
      if (text.endsWith('.')) {
        buffer.writeln('</p>');
        inParagraph = false;
      }
    }

    if (inParagraph) buffer.writeln('</p>');
    return buffer.toString();
  }

  String _processReferenceLines(List<String> lines) {
    final buffer = StringBuffer();
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      buffer.writeln('<div class="csl-entry">${line.trim()}</div>');
    }
    return buffer.toString();
  }
}
