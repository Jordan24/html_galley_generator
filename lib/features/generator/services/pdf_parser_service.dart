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
    List<String> footnoteLines = [];

    // 1. Fallback to PDF Metadata
    final info = document.documentInformation;
    if (info.title.isNotEmpty) {
      title = _clean(info.title);
    }
    if (info.author.isNotEmpty) {
      authorFullName = _clean(info.author);
    }

    bool isAbstract = false;
    bool isKeywords = false;
    bool isReferences = false;
    bool isFootnotes = false;
    List<String> titleLines = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = _clean(line.text);
      final fontSize = line.fontSize;

      if (text.isEmpty) continue;

      // 1. Metadata Extraction (regardless of position)
      
      // Volume/Issue
      if (text.contains('Volume') && text.contains('Issue')) {
        final volMatch = RegExp(r'Volume\s+(\d+)').firstMatch(text);
        final issMatch = RegExp(r'Issue\s+(\d+)').firstMatch(text);
        if (volMatch != null) volume = volMatch.group(1)!;
        if (issMatch != null) issue = issMatch.group(1)!;
      }

      // Article ID from DOI (often in footer)
      if (text.contains('doi.org')) {
        // Extract the DOI URL part (handle optional protocol)
        final doiMatch = RegExp(r'(?:https?://)?doi\.org/[^\s]+').firstMatch(text);
        if (doiMatch != null) {
          String doiUrl = doiMatch.group(0)!;
          // Trim trailing punctuation that might be part of a sentence
          doiUrl = doiUrl.replaceAll(RegExp(r'[./,;]+$'), '');
          final parts = doiUrl.split('.');
          if (parts.isNotEmpty) {
            final lastPart = parts.last;
            if (RegExp(r'^\d+$').hasMatch(lastPart)) {
              articleId = lastPart;
            }
          }
        }
      }

      // 2. Footer and Header Detection
      final pageIndex = line.pageIndex;
      final pageHeight = document.pages[pageIndex].size.height;
      final isBottom = line.bounds.top > pageHeight * 0.92;

      // Skip lines that are purely page numbers or common footer text
      final isPageNumber = RegExp(r'^\d+$').hasMatch(text);
      final isJournalFooter = text.contains('Transnational Asia') || (text.contains('Volume') && text.contains('Issue'));

      if (isBottom || isPageNumber || isJournalFooter) {
        continue;
      }

      // 3. Title Detection
      // Heuristic: Large font (>13pt), near the top (first 20 lines)
      if (fontSize > 13.5 && i < 20) {
        titleLines.add(text);
        continue;
      }

      // If we found title lines and font size dropped, use them as priority over metadata
      if (titleLines.isNotEmpty && fontSize <= 13.5) {
        final extractedTitle = titleLines.join(' ');
        if (extractedTitle.length > title.length) {
          title = extractedTitle;
        }
        titleLines = []; // Reset to avoid re-triggering
      }

      // 4. Author Detection
      // Heuristic: Medium font (11-13pt), after title, near start
      if (authorFullName.isEmpty && title.isNotEmpty && fontSize >= 11.0 && fontSize <= 13.0 && i < 30) {
        if (!text.toLowerCase().contains('volume') && !text.toLowerCase().contains('issue') && !text.toLowerCase().contains('abstract')) {
          authorFullName = text;
        }
      }

      // 5. Section Detection
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
        isFootnotes = false;
        continue;
      } else if (lowerText == 'footnotes' || lowerText == 'notes') {
        isFootnotes = true;
        isAbstract = false;
        isKeywords = false;
        isReferences = false;
        continue;
      }

      // 6. Section Content
      if (isAbstract) {
        abstractText += ' $text';
      } else if (isKeywords) {
        keywords += text;
      } else if (isReferences) {
        referenceLines.add(text);
      } else if (isFootnotes) {
        footnoteLines.add(text);
      } else if (title.isNotEmpty && authorFullName.isNotEmpty && fontSize >= 8.5 && fontSize <= 13.5) {
        // Body content - include headers (larger font)
        if (text.length > 3) {
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
    final orcidPattern = RegExp(r'(\d{4}[-\s\.]\d{4}[-\s\.]\d{4}[-\s\.]\d{3}[0-9X])');
    var match = orcidPattern.firstMatch(fullText);
    match ??= orcidPattern.firstMatch(info.keywords);
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
    if (match != null) {
      authorOrcid = match.group(1)!.replaceAll(RegExp(r'[\s\.]'), '-');
    }

    // 10. DOI/Article ID Extraction from Annotations if not found in text
    if (articleId.isEmpty) {
      for (int i = 0; i < document.pages.count; i++) {
        final page = document.pages[i];
        for (int j = 0; j < page.annotations.count; j++) {
          final annotation = page.annotations[j];
          if (annotation is PdfUriAnnotation) {
            final uri = annotation.uri;
            if (uri.contains('doi.org')) {
              String doiUrl = uri.replaceAll(RegExp(r'[./,;]+$'), '');
              final parts = doiUrl.split('.');
              if (parts.isNotEmpty) {
                final lastPart = parts.last;
                if (RegExp(r'^\d+$').hasMatch(lastPart)) {
                  articleId = lastPart;
                  break;
                }
              }
            }
          }
        }
        if (articleId.isNotEmpty) break;
      }
    }

    document.dispose();

    // Secondary cleaning/stripping
    abstractText = abstractText.replaceFirst('Abstract ', '').trim();
    keywords = keywords.replaceFirst('Keywords ', '').trim();

    return ArticleMetadata(
      title: title,
      author: authorFullName.split(' ').last.toUpperCase(),
      authorFullName: authorFullName,
      authorFirstName: authorFullName.isNotEmpty ? authorFullName.split(' ').first : '',
      authorLastName: authorFullName.isNotEmpty ? authorFullName.split(' ').last : '',
      abstract_: abstractText,
      keywords: keywords,
      articleBodyHtml: _processBodyLines(bodyLines),
      articleBibliography: _processReferenceLines(referenceLines),
      articleFootnotes: _processFootnoteLines(footnoteLines),
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
      issuedDate: DateTime.now().toString().split(' ').first,
      publishedDateMonYYYY: _formatMonYYYY(DateTime.now()),
      publishYear: DateTime.now().year.toString(),
      submittedDate: DateTime.now().toString().split(' ').first,
      modifiedDate: DateTime.now().toString().split(' ').first,
      titleMain: 'Transnational Asia', // Default or extracted
      issueId: '', 
    );
  }

  String _formatMonYYYY(DateTime date) {
    final months = ['Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'June', 'July', 'Aug.', 'Sept.', 'Oct.', 'Nov.', 'Dec.'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _clean(String text) {
    if (text.isEmpty) return '';
    return text.trim()
      .replaceAll('\uFFFD', "'")
      .replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u2032\u2035\u02BC\u02BD\u02C8\u02CA\u02CB\u00B4\u0060\u0090\u0091\u0092]'), "'")
      .replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F\u2033\u2036\u0093\u0094\u00AB\u00BB]'), '"')
      .replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'), '-')
      .replaceAll('\uFB01', 'fi')
      .replaceAll('\uFB02', 'fl')
      .replaceAll(RegExp(r'[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\uFEFF]'), ' ')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _processBodyLines(List<String> lines) {
    final buffer = StringBuffer();
    bool inParagraph = false;

    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.isEmpty) continue;

      // Header heuristic:
      // 1. Short line (< 100 chars)
      // 2. Doesn't end with a period, comma, or semicolon
      // 3. Or it's one of the standard section titles
      final isHeader = (text.length < 100 && !RegExp(r'[.,;]$').hasMatch(text)) || 
                       RegExp(r'^(Introduction|Conclusion|Discussion|Results|Methods|Background|Bibliography|References)$', caseSensitive: false).hasMatch(text);

      if (isHeader) {
        if (inParagraph) {
          buffer.writeln('</p>');
          inParagraph = false;
        }
        buffer.writeln('<h2>$text</h2>');
      } else {
        if (!inParagraph) {
          buffer.write('<p>');
          inParagraph = true;
        }
        buffer.write('$text ');

        // End of paragraph heuristic: ends with period and next line is likely a header or long gap
        if (text.endsWith('.') && i < lines.length - 1) {
          final nextLine = lines[i+1].trim();
          final nextIsHeader = (nextLine.length < 100 && !RegExp(r'[.,;]$').hasMatch(nextLine));
          if (nextIsHeader) {
            buffer.writeln('</p>');
            inParagraph = false;
          }
        }
      }
    }

    if (inParagraph) buffer.writeln('</p>');
    return buffer.toString();
  }

  String _processReferenceLines(List<String> lines) {
    if (lines.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('<h2>Bibliography</h2>');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      buffer.writeln('<div class="csl-entry">${line.trim()}</div>');
    }
    return buffer.toString();
  }

  String _processFootnoteLines(List<String> lines) {
    if (lines.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('<h2>Notes</h2>');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      buffer.writeln('<p>${line.trim()}</p>');
    }
    return buffer.toString();
  }
}
