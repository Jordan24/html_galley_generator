import 'dart:io';
import 'dart:ui' show Rect;
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
    String volume = '';
    String issue = '';
    String articleId = '';
    String authorOrcid = '';
    String authorAffiliation = '';
    String authorBio = '';
    List<_RichLine> abstractRichLines = [];
    List<_RichLine> keywordsRichLines = [];
    List<_RichLine> bodyRichLines = [];
    List<_RichLine> footnoteLines = [];

    // 1. Fallback to PDF Metadata
    final info = document.documentInformation;
    if (info.title.isNotEmpty) {
      title = _clean(info.title);
    }
    if (info.author.isNotEmpty) {
      authorFullName = _clean(info.author);
    }

    // 2. Build a per-page map of URI annotations (bounds → uri) for link detection
    final Map<int, List<_LinkAnnotation>> pageLinks = {};
    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final List<_LinkAnnotation> links = [];
      for (int j = 0; j < page.annotations.count; j++) {
        final annotation = page.annotations[j];
        if (annotation is PdfUriAnnotation && annotation.uri.isNotEmpty) {
          links.add(_LinkAnnotation(annotation.bounds, annotation.uri));
        }
      }
      if (links.isNotEmpty) pageLinks[i] = links;
    }

    // 3. Process Lines into RichLines for geometric analysis
    final List<_RichLine> allRichLines = [];
    for (final line in lines) {
      final pageIndex = line.pageIndex;
      final pageLinksForPage = pageLinks[pageIndex] ?? [];
      
      final List<_RichWord> richWords = [];
      for (final word in line.wordCollection) {
        final cleaned = _clean(word.text);
        if (cleaned.isEmpty) continue;
        final uri = _findLinkForBounds(word.bounds, pageLinksForPage);
        richWords.add(_RichWord(
          text: cleaned,
          bounds: word.bounds,
          fontSize: word.fontSize,
          fontStyle: word.fontStyle,
          pageIndex: pageIndex,
          uri: uri,
        ));
      }
      
      if (richWords.isNotEmpty) {
        allRichLines.add(_RichLine(
          words: richWords,
          text: _clean(line.text),
          bounds: line.bounds,
          fontSize: line.fontSize,
        ));
      }
    }

    // Calculate document baselines
    final standardMargin = _calculateStandardMargin(allRichLines);
    final standardLineHeight = _calculateStandardLineHeight(allRichLines);

    bool isAbstract = false;
    bool isKeywords = false;
    bool isFootnotes = false;
    List<String> titleLines = [];

    for (int i = 0; i < allRichLines.length; i++) {
      final richLine = allRichLines[i];
      final text = richLine.plainText;
      final fontSize = richLine.fontSize;

      if (text.isEmpty) continue;

      // --- Metadata Extraction (Restored from working version) ---
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

    final abstractHtml = _processBodyRichLines(abstractRichLines, standardMargin, standardLineHeight).trim();
    final keywordsHtml = _processBodyRichLines(keywordsRichLines, standardMargin, standardLineHeight).trim();

    String _cleanHtmlToPlainText(String html) {
      return html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAll('\uFFFD', "'");
    }

    final abstractText = _cleanHtmlToPlainText(abstractHtml);
    final keywords = _cleanHtmlToPlainText(keywordsHtml);

    final consolidatedBody = StringBuffer();
    if (abstractHtml.isNotEmpty) {
      consolidatedBody.writeln('<h2>Abstract</h2>');
      consolidatedBody.writeln(abstractHtml);
    }
    if (keywordsHtml.isNotEmpty) {
      consolidatedBody.writeln('<h2>Keywords</h2>');
      consolidatedBody.writeln(keywordsHtml);
    }
    consolidatedBody.writeln(_processBodyRichLines(bodyRichLines, standardMargin, standardLineHeight));
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

  // ---------------------------------------------------------------------------
  // Geometric Helpers for Baselines
  // ---------------------------------------------------------------------------

  double _calculateStandardMargin(List<_RichLine> lines) {
    if (lines.isEmpty) return 0.0;
    final Map<int, int> counts = {};
    for (final line in lines) {
      final left = line.bounds.left.round();
      counts[left] = (counts[left] ?? 0) + 1;
    }
    // Return the most frequent left margin
    var maxCount = -1;
    var mostFrequent = 0.0;
    counts.forEach((left, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequent = left.toDouble();
      }
    });
    return mostFrequent;
  }

  double _calculateStandardLineHeight(List<_RichLine> lines) {
    if (lines.length < 2) return 12.0;
    final Map<int, int> counts = {};
    for (int i = 0; i < lines.length - 1; i++) {
      final current = lines[i];
      final next = lines[i + 1];
      if (current.pageIndex == next.pageIndex) {
        final diff = (next.bounds.top - current.bounds.top).round();
        if (diff > 5 && diff < 50) { // Reasonable range for line heights
          counts[diff] = (counts[diff] ?? 0) + 1;
        }
      }
    }
    var maxCount = -1;
    var mostFrequent = 12.0;
    counts.forEach((diff, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequent = diff.toDouble();
      }
    });
    return mostFrequent;
  }

  // ---------------------------------------------------------------------------
  // Body / section processors
  // ---------------------------------------------------------------------------

  String _processBodyRichLines(List<_RichLine> lines, double standardMargin, double standardLineHeight) {
    final buffer = StringBuffer();
    bool inParagraph = false;
    bool inBlockquote = false;

    for (int i = 0; i < lines.length; i++) {
      final richLine = lines[i];
      final plainText = richLine.plainText;
      if (plainText.isEmpty) continue;

      // --- 1. Header Detection (Enhanced) ---
      final isExplicitHeader = RegExp(
        r'^(\d+\.?\s*)?(Introduction|Conclusion|Discussion|Results|Methods|Background|Bibliography|References|Notes|Footnotes|About the Author|Acknowledgements)',
        caseSensitive: false,
      ).hasMatch(plainText);
      
      // Header heuristic: short, larger font, or extra vertical space
      bool isHeader = isExplicitHeader || (richLine.fontSize > 13.0 && plainText.length < 100);
      
      // Check vertical space before
      if (i > 0 && !isHeader) {
        final prev = lines[i-1];
        if (richLine.pageIndex == prev.pageIndex) {
          final gap = richLine.bounds.top - prev.bounds.top;
          if (gap > standardLineHeight * 1.8 && plainText.length < 80 && !RegExp(r'[.,;]$').hasMatch(plainText)) {
            isHeader = true;
          }
        }
      }

      if (isHeader) {
        if (inParagraph) buffer.writeln('</p>');
        if (inBlockquote) buffer.writeln('</blockquote>');
        inParagraph = false;
        inBlockquote = false;
        buffer.writeln('<h2>${_toRichHtml(richLine)}</h2>');
        continue;
      }

      // --- 1b. Figure/Table Detection ---
      final isFigureCaption = RegExp(r'^(Figure|Fig\.?)\s+\d+', caseSensitive: false).hasMatch(plainText);
      final isTableCaption = RegExp(r'^Table\s+\d+', caseSensitive: false).hasMatch(plainText);

      if (isFigureCaption) {
        if (inParagraph) buffer.writeln('</p>');
        if (inBlockquote) buffer.writeln('</blockquote>');
        inParagraph = false;
        inBlockquote = false;
        
        final figureMatch = RegExp(r'^(Figure|Fig\.?)\s+\d+', caseSensitive: false).firstMatch(plainText);
        final figureLabel = figureMatch?.group(0) ?? "Figure";
        final figureId = figureLabel.replaceAll(RegExp(r'[^0-9]'), '');
        
        buffer.writeln('<figure>');
        buffer.writeln('\t\t<img width="575" src="/sites/g/files/REPLACE_ME/f/Figure_$figureId.jpg" alt="${_clean(plainText)}">');
        buffer.writeln('\t\t<figcaption>');
        buffer.writeln('\t\t\t<p style="font-size: 12px;">${_toRichHtml(richLine)}</p>');
        buffer.writeln('\t\t</figcaption>');
        buffer.writeln('</figure>');
        continue;
      } else if (isTableCaption) {
        if (inParagraph) buffer.writeln('</p>');
        if (inBlockquote) buffer.writeln('</blockquote>');
        inParagraph = false;
        inBlockquote = false;

        final tableMatch = RegExp(r'^Table\s+\d+', caseSensitive: false).firstMatch(plainText);
        final tableLabel = tableMatch?.group(0) ?? "Table";

        buffer.writeln('<div class="table-wrapper">');
        buffer.writeln('\t\t<p style="font-size: 12px;">${_toRichHtml(richLine)}</p>');
        buffer.writeln('\t\t<table border="1" style="width: 100%; border-collapse: collapse; margin-top: 10px;">');
        buffer.writeln('\t\t\t<tr><td style="padding: 20px; text-align: center; border: 1px dashed #28a745;">[ REPLACE WITH $tableLabel CONTENT ]</td></tr>');
        buffer.writeln('\t\t</table>');
        buffer.writeln('</div>');
        continue;
      }

      // --- 2. Blockquote / Indentation Detection ---
      // We'll treat significant indentation as a blockquote, 
      // but minor indentation as just a new paragraph start.
      final isIndented = richLine.bounds.left > standardMargin + 5;
      final isBlockquote = richLine.bounds.left > standardMargin + 25;

      if (isBlockquote && !inBlockquote) {
        if (inParagraph) buffer.writeln('</p>');
        inParagraph = false;
        buffer.writeln('<blockquote>');
        inBlockquote = true;
      } else if (!isBlockquote && inBlockquote) {
        buffer.writeln('</blockquote>');
        inBlockquote = false;
      }

      // --- 3. Paragraph Detection (Vertical Spacing & Indentation) ---
      bool startNewParagraph = false;
      if (i > 0) {
        final prev = lines[i - 1];
        if (richLine.pageIndex == prev.pageIndex) {
          final gap = richLine.bounds.top - prev.bounds.top;
          final prevEndsWithPeriod = prev.plainText.trim().endsWith('.');
          
          // Heuristic: If previous line ends with period, we are more sensitive to gaps
          final threshold = prevEndsWithPeriod ? 1.15 : 1.3;
          
          if (gap > standardLineHeight * threshold) {
            startNewParagraph = true;
          } else if (isIndented && !isBlockquote && gap > standardLineHeight * 0.8) {
            // Indentation usually marks a new paragraph even with normal spacing
            startNewParagraph = true;
          }
        } else {
          // New page: Check if the first line is indented or the previous page ended with a period
          if (isIndented) startNewParagraph = true;
        }
      }

      if (startNewParagraph && inParagraph) {
        buffer.writeln('</p>');
        inParagraph = false;
      }

      if (!inParagraph) {
        buffer.write('<p>');
        inParagraph = true;
      }

      buffer.write('${_toRichHtml(richLine)} ');

      // End paragraph heuristic
      if (plainText.endsWith('.') && i < lines.length - 1) {
        final next = lines[i + 1];
        if (next.pageIndex == richLine.pageIndex) {
          final gap = next.bounds.top - richLine.bounds.top;
          if (gap > standardLineHeight * 1.25) {
            buffer.writeln('</p>');
            inParagraph = false;
          }
        }
      }
    }

    if (inParagraph) buffer.writeln('</p>');
    if (inBlockquote) buffer.writeln('</blockquote>');
    return buffer.toString();
  }

  String _toRichHtml(_RichLine line) {
    if (line.words.isEmpty) return '';
    final buffer = StringBuffer();
    
    List<_RichWord> currentGroup = [];

    void flushGroup() {
      if (currentGroup.isEmpty) return;
      
      final first = currentGroup[0];
      String text = currentGroup.map((w) => w.text).join(' ').replaceAll(' - ', '-');
      if (text.trim().isEmpty) {
        currentGroup = [];
        return;
      }
      
      // Superscript detection
      // Heuristic: smaller font AND baseline is higher than the line's center
      final isSuperscript = first.fontSize < line.fontSize * 0.9 && 
                           first.bounds.top < line.bounds.top + (line.bounds.height * 0.2);
      
      String span = _translateInlineMarkdown(text);
      
      final trimmedSpan = span.trim();
      final footnoteMatch = RegExp(r'^\[?(\d+)\]?$').firstMatch(trimmedSpan);
      final isFootnoteRef = isSuperscript && footnoteMatch != null;
      
      if (isFootnoteRef) {
        final id = footnoteMatch.group(1)!;
        span = '<sup id="ref$id"><a href="#fn$id">$id</a></sup>';
      } else {
        // Apply styles in consistent order
        if (first.isItalic) span = '<i>$span</i>';
        if (first.isBold) span = '<b>$span</b>';
        if (isSuperscript) span = '<sup>$span</sup>';
      }
      
      if (first.uri != null) {
        final isMetadataLink = first.uri!.contains('doi.org') || first.uri!.contains('orcid.org');
        if (!isMetadataLink) {
          span = '<a href="${first.uri}">$span</a>';
        }
      }
      
      buffer.write('$span ');
      currentGroup = [];
    }

    for (final word in line.words) {
      final isSuperscript = word.fontSize < line.fontSize * 0.9 && 
                           word.bounds.top < line.bounds.top + (line.bounds.height * 0.2);
      
      if (currentGroup.isEmpty) {
        currentGroup.add(word);
      } else {
        final prev = currentGroup.last;
        final prevIsSuperscript = prev.fontSize < line.fontSize * 0.9 && 
                                 prev.bounds.top < line.bounds.top + (line.bounds.height * 0.2);
        
        bool sameStyle = prev.isBold == word.isBold && 
                         prev.isItalic == word.isItalic && 
                         prevIsSuperscript == isSuperscript && 
                         prev.uri == word.uri;
        
        if (sameStyle) {
          currentGroup.add(word);
        } else {
          flushGroup();
          currentGroup.add(word);
        }
      }
    }
    flushGroup();
    
    return buffer.toString().trimRight();
  }



  String _processFootnoteLines(List<_RichLine> lines) {
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
          final stripped = _stripPrefix(line, prefixRegex) ?? _RichLine(words: [], text: '', bounds: line.bounds, fontSize: line.fontSize);
          footnotes[id] = _toRichHtml(stripped);
          continue;
        }
      }

      // If no match, append to current footnote if we have one
      if (currentId != null) {
        footnotes[currentId] = '${footnotes[currentId]} ${_toRichHtml(line)}';
      } else {
        // Fallback: just output the line as is
        buffer.writeln('<p>${_toRichHtml(line)}</p>');
      }
    }

    // Output footnotes in sorted numerical order
    final sortedKeys = footnotes.keys.toList()..sort();
    for (final id in sortedKeys) {
      final cleanHtml = footnotes[id]!.trim();
      buffer.writeln('<p id="fn$id"><sup><a href="#ref$id">$id</a></sup> $cleanHtml</p>');
    }

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? _findLinkForBounds(Rect wordBounds, List<_LinkAnnotation> links) {
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

  _RichLine? _stripPrefix(_RichLine line, RegExp prefixRegex) {
    final text = line.plainText;
    final match = prefixRegex.firstMatch(text);
    if (match == null) return line;
    
    final matchedLength = match.group(0)!.length;
    if (matchedLength >= text.length) return null; // Entire line was the prefix
    
    // Find which words to keep
    int charsCount = 0;
    final newWords = <_RichWord>[];
    for (final word in line.words) {
      charsCount += word.text.length + 1; // plus space
      if (charsCount > matchedLength) {
        // If this word contains the boundary, we might need to slice it
        final wordStartInLine = text.indexOf(word.text);
        if (wordStartInLine >= 0) {
          final wordEndInLine = wordStartInLine + word.text.length;
          if (wordEndInLine <= matchedLength) {
            // Word is entirely within the prefix, skip it
            continue;
          } else if (wordStartInLine < matchedLength) {
            // Word overlaps the boundary, slice it
            final slicedText = word.text.substring(matchedLength - wordStartInLine);
            newWords.add(_RichWord(
              text: slicedText,
              bounds: word.bounds,
              fontSize: word.fontSize,
              fontStyle: word.fontStyle,
              pageIndex: word.pageIndex,
              uri: word.uri,
            ));
          } else {
            // Word is entirely after the prefix, keep it
            newWords.add(word);
          }
        }
      }
    }
    
    if (newWords.isEmpty) return null;
    return _RichLine(
      words: newWords,
      text: text.substring(matchedLength).trim(),
      bounds: line.bounds,
      fontSize: line.fontSize,
    );
  }

  String _translateInlineMarkdown(String text) {
    if (text.isEmpty) return text;
    String result = text;
    result = _replacePairs(result, '**', '<b>', '</b>');
    result = _replacePairs(result, '__', '<b>', '</b>');
    result = _replacePairs(result, '*', '<i>', '</i>');
    result = _replacePairs(result, '_', '<i>', '</i>');
    return result;
  }

  String _replacePairs(String text, String marker, String openTag, String closeTag) {
    int index = 0;
    bool isOpen = false;
    final buffer = StringBuffer();
    
    while (index < text.length) {
      if (text.startsWith(marker, index)) {
        if (!isOpen) {
          buffer.write(openTag);
          isOpen = true;
        } else {
          buffer.write(closeTag);
          isOpen = false;
        }
        index += marker.length;
      } else {
        buffer.write(text[index]);
        index++;
      }
    }
    
    String result = buffer.toString();
    if (isOpen) {
      result += closeTag;
    }
    return result;
  }

  String _clean(String text) {
    if (text.isEmpty) return '';
    return text
        .trim()
        .replaceAll('\uFFFD', "'")
        .replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u2032\u2035\u02BC\u02BD\u02C8\u02CA\u02CB\u00B4\u0060\u0090\u0091\u0092]'), "'")
        .replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F\u2033\u2036\u0093\u0094\u00AB\u00BB]'), '"')
        .replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'), '-')
        .replaceAll('\uFB01', 'fi')
        .replaceAll('\uFB02', 'fl')
        .replaceAll(RegExp(r'[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\uFEFF]'), ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' - ', '-');
  }
}

// ---------------------------------------------------------------------------
// Internal Geometric Models
// ---------------------------------------------------------------------------

class _RichWord {
  final String text;
  final Rect bounds;
  final double fontSize;
  final List<PdfFontStyle> fontStyle;
  final int pageIndex;
  final String? uri;

  _RichWord({
    required this.text,
    required this.bounds,
    required this.fontSize,
    required this.fontStyle,
    required this.pageIndex,
    this.uri,
  });

  bool get isBold => fontStyle.contains(PdfFontStyle.bold);
  bool get isItalic => fontStyle.contains(PdfFontStyle.italic);
}

class _RichLine {
  final List<_RichWord> words;
  final String text;
  final Rect bounds;
  final double fontSize;

  _RichLine({
    required this.words,
    required this.text,
    required this.bounds,
    required this.fontSize,
  });

  String get plainText => text;
  int get pageIndex => words.first.pageIndex;
}

class _LinkAnnotation {
  final Rect bounds;
  final String uri;
  const _LinkAnnotation(this.bounds, this.uri);
}
