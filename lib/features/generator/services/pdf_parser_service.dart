import 'dart:io';
import 'dart:ui' show Rect;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/article_metadata.dart';
import '../utils/string_cleaner.dart';
import '../utils/pdf_layout_analyzer.dart';

/// Service class responsible for loading and extracting metadata and HTML paragraphs from a PDF file.
/// Delegates geometric layout analyze checks to [PdfLayoutAnalyzer].
class PdfParserService {
  Future<ArticleMetadata> parse(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final lines = extractor.extractTextLines();
    final fullText = extractor.extractText();

    String title = '';
    String authorFullName = '';
    String volume = '';
    String issue = '';
    String articleId = '';
    String authorOrcid = '';
    String authorAffiliation = '';
    String authorBio = '';
    List<RichLine> abstractRichLines = [];
    List<RichLine> keywordsRichLines = [];
    List<RichLine> bodyRichLines = [];
    List<RichLine> footnoteLines = [];

    // 1. Fallback to PDF Metadata
    final info = document.documentInformation;
    if (info.title.isNotEmpty) {
      title = _clean(info.title);
    }
    if (info.author.isNotEmpty) {
      authorFullName = _clean(info.author);
    }

    // 2. Build a per-page map of URI annotations (bounds → uri) for link detection
    final Map<int, List<LinkAnnotation>> pageLinks = {};
    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final List<LinkAnnotation> links = [];
      for (int j = 0; j < page.annotations.count; j++) {
        final annotation = page.annotations[j];
        if (annotation is PdfUriAnnotation && annotation.uri.isNotEmpty) {
          links.add(LinkAnnotation(annotation.bounds, annotation.uri));
        }
      }
      if (links.isNotEmpty) pageLinks[i] = links;
    }

    // 3. Process Lines into RichLines for geometric analysis
    final List<RichLine> allRichLines = [];
    for (final line in lines) {
      final pageIndex = line.pageIndex;
      final pageLinksForPage = pageLinks[pageIndex] ?? [];
      
      final List<RichWord> richWords = [];
      for (final word in line.wordCollection) {
        final cleaned = _clean(word.text);
        if (cleaned.isEmpty) continue;
        final uri = _findLinkForBounds(word.bounds, pageLinksForPage);
        richWords.add(RichWord(
          text: cleaned,
          bounds: word.bounds,
          fontSize: word.fontSize,
          fontStyle: word.fontStyle,
          pageIndex: pageIndex,
          uri: uri,
        ));
      }
      
      if (richWords.isNotEmpty) {
        allRichLines.add(RichLine(
          words: richWords,
          text: _clean(line.text),
          bounds: line.bounds,
          fontSize: line.fontSize,
        ));
      }
    }

    // Calculate document baselines via PdfLayoutAnalyzer
    final standardMargin = PdfLayoutAnalyzer.calculateStandardMargin(allRichLines);
    final standardLineHeight = PdfLayoutAnalyzer.calculateStandardLineHeight(allRichLines);

    bool isAbstract = false;
    bool isKeywords = false;
    bool isFootnotes = false;
    List<String> titleLines = [];

    for (int i = 0; i < allRichLines.length; i++) {
      final richLine = allRichLines[i];
      final text = richLine.plainText;
      final fontSize = richLine.fontSize;

      if (text.isEmpty) continue;

      // --- Metadata Extraction ---
      if (text.contains('Volume') && text.contains('Issue')) {
        final volMatch = RegExp(r'Volume\s+(\d+)').firstMatch(text);
        final issMatch = RegExp(r'Issue\s+(\d+)').firstMatch(text);
        if (volMatch != null) volume = volMatch.group(1)!;
        if (issMatch != null) issue = issMatch.group(1)!;
      }

      if (text.contains('doi.org')) {
        final doiMatch = RegExp(r'(?:https?://)?doi\.org/[^\s]+').firstMatch(text);
        if (doiMatch != null) {
          String doiUrl = doiMatch.group(0)!;
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

      // --- Footer and Header Detection ---
      final pageIndex = richLine.pageIndex;
      final pageHeight = document.pages[pageIndex].size.height;
      final isBottom = richLine.bounds.top > pageHeight * 0.92;

      final isPageNumber = RegExp(r'^\d+$').hasMatch(text);
      final isJournalFooter =
          text.contains('Transnational Asia') || (text.contains('Volume') && text.contains('Issue'));

      if (isBottom || isPageNumber || isJournalFooter) {
        continue;
      }

      // --- Title Detection ---
      if (fontSize > 13.5 && i < 20) {
        titleLines.add(text);
        continue;
      }

      if (titleLines.isNotEmpty && fontSize <= 13.5) {
        final extractedTitle = titleLines.join(' ');
        if (extractedTitle.length > title.length) {
          title = extractedTitle;
        }
        titleLines = [];
      }

      // --- Author Detection ---
      if (authorFullName.isEmpty &&
          title.isNotEmpty &&
          fontSize >= 11.0 &&
          fontSize <= 13.0 &&
          i < 30) {
        if (!text.toLowerCase().contains('volume') &&
            !text.toLowerCase().contains('issue') &&
            !text.toLowerCase().contains('abstract')) {
          authorFullName = text;
        }
      }

      // --- Section Detection ---
      final lowerText = text.toLowerCase();
      if (lowerText == 'abstract' || lowerText.startsWith('abstract:')) {
        isAbstract = true;
        isKeywords = false;
        if (lowerText.startsWith('abstract:')) {
          final stripped = _stripPrefix(richLine, RegExp(r'^[\s#*_]*abstract[:\s#*_]*', caseSensitive: false));
          if (stripped != null) abstractRichLines.add(stripped);
        }
        continue;
      } else if (lowerText == 'keywords' ||
          lowerText.startsWith('keywords:') ||
          lowerText.startsWith('keywords ')) {
        isKeywords = true;
        isAbstract = false;
        if (lowerText.startsWith('keywords:') || lowerText.startsWith('keywords ')) {
          final stripped = _stripPrefix(richLine, RegExp(r'^[\s#*_]*keywords[:\s#*_]*', caseSensitive: false));
          if (stripped != null) keywordsRichLines.add(stripped);
        }
        continue;
      } else if (lowerText == 'bibliography' || lowerText == 'references') {
        isAbstract = false;
        isKeywords = false;
        isFootnotes = false;
      } else if (lowerText == 'footnotes' || lowerText == 'notes') {
        isFootnotes = true;
        isAbstract = false;
        isKeywords = false;
        continue;
      }
 
      // Stop metadata sections if we hit a likely section header
      if (isAbstract || isKeywords) {
        final isExplicitHeader = RegExp(
          r'^(\d+\.?\s*|[A-Z]\.\s*)?(Introduction|Conclusion|Discussion|Results|Methods|Background|Bibliography|References|Notes|Footnotes|About the Author|Acknowledgements|Works Cited)',
          caseSensitive: false,
        ).hasMatch(text);
 
        if (isExplicitHeader) {
          isAbstract = false;
          isKeywords = false;
        }
      }
 
      // --- Section Content ---
      if (isAbstract) {
        abstractRichLines.add(richLine);
      } else if (isKeywords) {
        keywordsRichLines.add(richLine);
      } else if (isFootnotes) {
        footnoteLines.add(richLine);
      } else if (title.isNotEmpty && authorFullName.isNotEmpty && fontSize >= 8.5 && fontSize <= 13.5) {
        if (_clean(text) == _clean(authorFullName)) {
          continue;
        }
        if (text.length > 3) {
          bodyRichLines.add(richLine);
        }
      }
    }

    // --- Bio and Affiliation Extraction ---
    if (authorFullName.isNotEmpty) {
      final bioRegex = RegExp('${RegExp.escape(authorFullName)}\\s+is\\s+');
      for (int i = lines.length - 1; i >= 0; i--) {
        final line = lines[i];
        if (bioRegex.hasMatch(line.text)) {
          List<String> bioParts = [_clean(line.text)];
          int j = i + 1;
          while (j < lines.length) {
            final nextLine = lines[j];
            final nextText = _clean(nextLine.text);
            if (nextText.isEmpty) break;
            if (nextText.toLowerCase() == 'bibliography' || nextText == 'Bibliography') break;
            if (RegExp(r'^\d+$').hasMatch(nextText)) break;
            bioParts.add(nextText);
            j++;
          }
          authorBio = bioParts.join(' ');

          final affMatch = RegExp(
            r'at\s+(the\s+)?([^.]+University[^.]+|[^.]+Institute[^.]+|[^.]+College[^.]+)',
          ).firstMatch(authorBio);
          if (affMatch != null) {
            authorAffiliation = affMatch.group(2)!.trim();
          }
          break;
        }
      }
    }

    // --- ORCID Extraction ---
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

    // --- DOI/Article ID Extraction from Annotations if still not found ---
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

    final abstractHtml = PdfLayoutAnalyzer.processBodyRichLines(abstractRichLines, standardMargin, standardLineHeight).trim();
    final keywordsHtml = PdfLayoutAnalyzer.processBodyRichLines(keywordsRichLines, standardMargin, standardLineHeight).trim();

    String cleanHtmlToPlainText(String html) {
      return html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAll('\uFFFD', "'");
    }

    final abstractText = cleanHtmlToPlainText(abstractHtml);
    final keywords = cleanHtmlToPlainText(keywordsHtml);

    final consolidatedBody = StringBuffer();
    if (abstractHtml.isNotEmpty) {
      consolidatedBody.writeln('<h2>Abstract</h2>');
      consolidatedBody.writeln(abstractHtml);
    }
    if (keywordsHtml.isNotEmpty) {
      consolidatedBody.writeln('<h2>Keywords</h2>');
      consolidatedBody.writeln(keywordsHtml);
    }
    consolidatedBody.writeln(PdfLayoutAnalyzer.processBodyRichLines(bodyRichLines, standardMargin, standardLineHeight));
    consolidatedBody.writeln(_processFootnoteLines(footnoteLines));

    return ArticleMetadata(
      title: title,
      author: authorFullName.split(' ').last.toUpperCase(),
      authorFullName: authorFullName,
      authorFirstName: authorFullName.isNotEmpty ? authorFullName.split(' ').first : '',
      authorLastName: authorFullName.isNotEmpty ? authorFullName.split(' ').last : '',
      keywords:
          keywords.replaceFirst(RegExp(r'^keywords[:\s]*', caseSensitive: false), '').trim(),
      articleAbstract:
          abstractText.replaceFirst(RegExp(r'^abstract[:\s]*', caseSensitive: false), '').trim(),
      articleBody: consolidatedBody.toString(),
      authorOrcid: authorOrcid,
      authorAffiliation: authorAffiliation,
      authorBio: authorBio,
      volume: volume.isEmpty ? '7' : volume,
      issue: issue.isEmpty ? '1' : issue,
      articleId: articleId,
      submissionId: articleId,
      issueViewId: '',
      pdfGalleyId: '',
      publishedDate: DateTime.now().toString().split(' ').first,
      issuedDate: DateTime.now().toString().split(' ').first,
      publishedDateMonYYYY: _formatMonYYYY(DateTime.now()),
      publishYear: DateTime.now().year.toString(),
      submittedDate: DateTime.now().toString().split(' ').first,
      modifiedDate: DateTime.now().toString().split(' ').first,
      titleMain: title.contains(':') ? title.split(':').first.trim() : title,
    );
  }

  String _processFootnoteLines(List<RichLine> lines) {
    if (lines.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('<h2>Notes</h2>');

    final footnotes = <int, String>{};
    int? currentId;
    final prefixRegex = RegExp(r'^\[?(\d+)\]?\.?\s*');

    for (final line in lines) {
      final text = line.plainText;
      final match = prefixRegex.firstMatch(text);

      if (match != null) {
        final idStr = match.group(1)!;
        final id = int.tryParse(idStr);
        if (id != null) {
          currentId = id;
          final stripped = _stripPrefix(line, prefixRegex) ?? RichLine(words: [], text: '', bounds: line.bounds, fontSize: line.fontSize);
          footnotes[id] = PdfLayoutAnalyzer.toRichHtml(stripped);
          continue;
        }
      }

      if (currentId != null) {
        footnotes[currentId] = '${footnotes[currentId]} ${PdfLayoutAnalyzer.toRichHtml(line)}';
      } else {
        buffer.writeln('<p>${PdfLayoutAnalyzer.toRichHtml(line)}</p>');
      }
    }

    final sortedKeys = footnotes.keys.toList()..sort();
    for (final id in sortedKeys) {
      final cleanHtml = footnotes[id]!.trim();
      buffer.writeln('<p id="fn$id"><a href="#ref$id">[$id]</a> $cleanHtml</p>');
    }

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? _findLinkForBounds(Rect wordBounds, List<LinkAnnotation> links) {
    const double tolerance = 2.0;
    for (final link in links) {
      final lb = link.bounds;
      final overlapsH = wordBounds.left < lb.right + tolerance &&
          wordBounds.right > lb.left - tolerance;
      final overlapsV = wordBounds.top < lb.bottom + tolerance &&
          wordBounds.bottom > lb.top - tolerance;
      if (overlapsH && overlapsV) return link.uri;
    }
    return null;
  }

  String _formatMonYYYY(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  RichLine? _stripPrefix(RichLine line, RegExp prefixRegex) {
    final text = line.plainText;
    final match = prefixRegex.firstMatch(text);
    if (match == null) return line;
    
    final matchedLength = match.group(0)!.length;
    if (matchedLength >= text.length) return null;
    
    int charsCount = 0;
    final newWords = <RichWord>[];
    for (final word in line.words) {
      charsCount += word.text.length + 1;
      if (charsCount > matchedLength) {
        final wordStartInLine = text.indexOf(word.text);
        if (wordStartInLine >= 0) {
          final wordEndInLine = wordStartInLine + word.text.length;
          if (wordEndInLine <= matchedLength) {
            continue;
          } else if (wordStartInLine < matchedLength) {
            final slicedText = word.text.substring(matchedLength - wordStartInLine);
            newWords.add(RichWord(
              text: slicedText,
              bounds: word.bounds,
              fontSize: word.fontSize,
              fontStyle: word.fontStyle,
              pageIndex: word.pageIndex,
              uri: word.uri,
            ));
          } else {
            newWords.add(word);
          }
        }
      }
    }
    
    if (newWords.isEmpty) return null;
    return RichLine(
      words: newWords,
      text: text.substring(matchedLength).trim(),
      bounds: line.bounds,
      fontSize: line.fontSize,
    );
  }

  String _clean(String text) => StringCleaner.clean(text, normalizeHyphenSpaces: true);
}
