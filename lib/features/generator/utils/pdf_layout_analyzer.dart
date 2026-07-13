import 'dart:ui' show Rect;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'string_cleaner.dart';

/// Models a word parsed from a PDF, carrying font size, style flags, geometry, and link attributes.
class RichWord {
  final String text;
  final Rect bounds;
  final double fontSize;
  final List<PdfFontStyle> fontStyle;
  final int pageIndex;
  final String? uri;

  RichWord({
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

/// Models a line of rich text parsed from a PDF, consisting of multiple [RichWord] parts.
class RichLine {
  final List<RichWord> words;
  final String text;
  final Rect bounds;
  final double fontSize;

  RichLine({
    required this.words,
    required this.text,
    required this.bounds,
    required this.fontSize,
  });

  String get plainText => text;
  int get pageIndex => words.first.pageIndex;
}

/// Models a hyperlink bounding box annotation mapped to a URI address.
class LinkAnnotation {
  final Rect bounds;
  final String uri;
  const LinkAnnotation(this.bounds, this.uri);
}

/// Utility class for calculating and transforming raw coordinate-based PDF layout lines into structured HTML body blocks.
class PdfLayoutAnalyzer {
  /// Finds the dominant left-alignment margin value across a list of layout lines.
  static double calculateStandardMargin(List<RichLine> lines) {
    if (lines.isEmpty) return 0.0;
    final Map<int, int> counts = {};
    for (final line in lines) {
      final left = line.bounds.left.round();
      counts[left] = (counts[left] ?? 0) + 1;
    }
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

  /// Calculates the most frequent line spacing distance (line height) between successive lines on the same page.
  static double calculateStandardLineHeight(List<RichLine> lines) {
    if (lines.length < 2) return 12.0;
    final Map<int, int> counts = {};
    for (int i = 0; i < lines.length - 1; i++) {
      final current = lines[i];
      final next = lines[i + 1];
      if (current.pageIndex == next.pageIndex) {
        final diff = (next.bounds.top - current.bounds.top).round();
        if (diff > 5 && diff < 50) {
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

  /// Evaluates and groups lines of layout bounds into paragraph, blockquote, figure, and header structures.
  static String processBodyRichLines(List<RichLine> lines, double standardMargin, double standardLineHeight) {
    final buffer = StringBuffer();
    bool inParagraph = false;
    bool inBlockquote = false;

    for (int i = 0; i < lines.length; i++) {
      final richLine = lines[i];
      final plainText = richLine.plainText;
      if (plainText.isEmpty) continue;

      // Header Heuristics
      final isExplicitHeader = RegExp(
        r'^(\d+\.?\s*)?(Introduction|Conclusion|Discussion|Results|Methods|Background|Bibliography|References|Notes|Footnotes|About the Author|Acknowledgements)',
        caseSensitive: false,
      ).hasMatch(plainText);
      
      bool isHeader = isExplicitHeader || (richLine.fontSize > 13.0 && plainText.length < 100);
      
      if (i > 0 && !isHeader) {
        final prev = lines[i - 1];
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
        buffer.writeln('<h2>${toRichHtml(richLine)}</h2>');
        continue;
      }

      // Figure and Table Captions
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
        buffer.writeln('\t\t<img width="575" src="/sites/g/files/REPLACE_ME/f/Figure_$figureId.jpg" alt="${StringCleaner.clean(plainText, normalizeHyphenSpaces: true)}">');
        buffer.writeln('\t\t<figcaption>');
        buffer.writeln('\t\t\t<p style="font-size: 12px;">${toRichHtml(richLine)}</p>');
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
        buffer.writeln('\t\t<p style="font-size: 12px;">${toRichHtml(richLine)}</p>');
        buffer.writeln('\t\t<table border="1" style="width: 100%; border-collapse: collapse; margin-top: 10px;">');
        buffer.writeln('\t\t\t<tr><td style="padding: 20px; text-align: center; border: 1px dashed #28a745;">[ REPLACE WITH $tableLabel CONTENT ]</td></tr>');
        buffer.writeln('\t\t</table>');
        buffer.writeln('</div>');
        continue;
      }

      // Blockquotes (margin > 25px offset)
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

      // Paragraph spacing detection
      bool startNewParagraph = false;
      if (i > 0) {
        final prev = lines[i - 1];
        if (richLine.pageIndex == prev.pageIndex) {
          final gap = richLine.bounds.top - prev.bounds.top;
          final prevEndsWithPeriod = prev.plainText.trim().endsWith('.');
          final threshold = prevEndsWithPeriod ? 1.15 : 1.3;
          
          if (gap > standardLineHeight * threshold) {
            startNewParagraph = true;
          } else if (isIndented && !isBlockquote && gap > standardLineHeight * 0.8) {
            startNewParagraph = true;
          }
        } else {
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

      buffer.write('${toRichHtml(richLine)} ');

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

  /// Converts a [RichLine] carrying multiple formatted layout words into a formatted HTML string.
  static String toRichHtml(RichLine line) {
    if (line.words.isEmpty) return '';
    final buffer = StringBuffer();
    
    List<RichWord> currentGroup = [];

    void flushGroup() {
      if (currentGroup.isEmpty) return;
      
      final first = currentGroup[0];
      String text = currentGroup.map((w) => w.text).join(' ').replaceAll(' - ', '-');
      if (text.trim().isEmpty) {
        currentGroup = [];
        return;
      }
      
      final isSuperscript = first.fontSize < line.fontSize * 0.9 && 
                           first.bounds.top < line.bounds.top + (line.bounds.height * 0.2);
      
      String span = translateInlineMarkdown(text);
      
      final trimmedSpan = span.trim();
      final footnoteMatch = RegExp(r'^\[?(\d+)\]?$').firstMatch(trimmedSpan);
      final isFootnoteRef = isSuperscript && footnoteMatch != null;
      
      if (isFootnoteRef) {
        final id = footnoteMatch.group(1)!;
        span = '<sup id="ref$id"><a href="#fn$id">[$id]</a></sup>';
      } else {
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
      
      buffer.write(span);
      currentGroup = [];
    }

    for (final word in line.words) {
      if (currentGroup.isEmpty) {
        currentGroup.add(word);
      } else {
        final prev = currentGroup.last;
        final hasSameStyle = prev.isBold == word.isBold && 
                             prev.isItalic == word.isItalic && 
                             (prev.uri == word.uri) &&
                             (prev.fontSize - word.fontSize).abs() < 0.5;
        if (hasSameStyle) {
          currentGroup.add(word);
        } else {
          flushGroup();
          currentGroup.add(word);
        }
      }
    }
    flushGroup();

    return buffer.toString();
  }

  /// Resolves markdown markers `**` and `*` into appropriate bold/italic HTML tags.
  static String translateInlineMarkdown(String text) {
    if (text.isEmpty) return text;
    String result = text;
    result = StringCleaner.replacePairs(result, '**', '<b>', '</b>');
    result = StringCleaner.replacePairs(result, '__', '<b>', '</b>');
    result = StringCleaner.replacePairs(result, '*', '<i>', '</i>');
    result = StringCleaner.replacePairs(result, '_', '<i>', '</i>');
    return result;
  }
}
