import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:docx_to_markdown/docx_to_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/article_metadata.dart';

class DocxParserService {
  Future<ArticleMetadata> parse(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Extract basic metadata: DOI -> articleId from footer/header
    String articleId = '';
    for (final zipFile in archive.files) {
      if (zipFile.name.startsWith('word/footer') || zipFile.name.startsWith('word/header')) {
        try {
          final xmlStr = utf8.decode(zipFile.content);
          final plainText = xmlStr.replaceAll(RegExp(r'<[^>]*>'), '');
          if (plainText.contains('doi.org')) {
             final doiMatch = RegExp(r'(?:https?://)?doi\.org/[^\s<>"]+').firstMatch(plainText);
             if (doiMatch != null) {
               String doiUrl = doiMatch.group(0)!;
               doiUrl = doiUrl.replaceAll(RegExp(r'[./,;]+$'), '');
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
        } catch (_) {}
      }
    }

    // Extract fallback Title and Creator from core.xml if needed
    String fallbackTitle = '';
    String fallbackCreator = '';
    final coreXmlFile = archive.findFile('docProps/core.xml');
    if (coreXmlFile != null) {
       try {
         final coreXml = XmlDocument.parse(utf8.decode(coreXmlFile.content));
         final titleNode = coreXml.findAllElements('dc:title').firstOrNull;
         if (titleNode != null) fallbackTitle = titleNode.innerText.trim();
         final creatorNode = coreXml.findAllElements('dc:creator').firstOrNull;
         if (creatorNode != null) fallbackCreator = creatorNode.innerText.trim();
       } catch (_) {}
    }

    // Preprocess XML files to clean up spelling error tags and merge adjacent runs with same format
    final modifiedXmls = <String, List<int>>{};
    for (final zipFile in archive.files) {
      if (zipFile.name == 'word/document.xml' || zipFile.name == 'word/footnotes.xml' || zipFile.name == 'word/endnotes.xml') {
        try {
          final xmlStr = utf8.decode(zipFile.content);
          final document = XmlDocument.parse(xmlStr);
          
          document.findAllElements('w:proofErr').toList().forEach((node) {
            node.parent?.children.remove(node);
          });
          
          _mergeAdjacentRuns(document);
          
          modifiedXmls[zipFile.name] = utf8.encode(document.toXmlString());
        } catch (_) {}
      }
    }
    
    Uint8List docxBytes = bytes;
    if (modifiedXmls.isNotEmpty) {
      try {
        final newArchive = Archive();
        for (final zipFile in archive.files) {
          if (modifiedXmls.containsKey(zipFile.name)) {
            final newBytes = modifiedXmls[zipFile.name]!;
            newArchive.addFile(ArchiveFile(zipFile.name, newBytes.length, newBytes));
          } else {
            newArchive.addFile(zipFile);
          }
        }
        docxBytes = Uint8List.fromList(ZipEncoder().encode(newArchive)!);
      } catch (_) {
        docxBytes = bytes;
      }
    }

    // Convert DOCX to Markdown
    final converter = DocxConverter(docxBytes);
    String markdown = await converter.convert();

    // Preprocess Markdown
    // 1. Clean leading/inline link anchors that might pollute headers/text
    String cleanMarkdown = markdown.replaceAll(RegExp(r'''<a\s+id=["'][\w\d]+["']>\s*</a>'''), '');

    // 2. Extract Footnotes
    final footnotesMap = <String, String>{};
    final fnDefRegex = RegExp(r'^\[\^([^\]]+)\]:\s*(.*)$', multiLine: true);
    final matches = fnDefRegex.allMatches(cleanMarkdown).toList();
    
    for (final match in matches.reversed) {
      final id = match.group(1)!;
      final content = match.group(2)!.trim();
      
      final robustContent = _convertMarkdownToHtmlRobustly(content);
      final contentHtml = md.markdownToHtml(robustContent, extensionSet: md.ExtensionSet.gitHubFlavored).trim();
      String cleanHtml = contentHtml;
      if (cleanHtml.startsWith('<p>') && cleanHtml.endsWith('</p>')) {
        cleanHtml = cleanHtml.substring(3, cleanHtml.length - 4);
      }
      
      footnotesMap[id] = cleanHtml;
      cleanMarkdown = cleanMarkdown.substring(0, match.start) + cleanMarkdown.substring(match.end);
    }
    
    // Replace inline footnote references
    cleanMarkdown = cleanMarkdown.replaceAllMapped(RegExp(r'\[\^([^\]]+)\]'), (m) {
      final id = m.group(1)!;
      return '<sup id="ref$id"><a href="#fn$id">$id</a></sup>';
    });

    // Split remaining content into paragraphs
    final paragraphs = cleanMarkdown.split(RegExp(r'\n\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Helpers
    String cleanMarkdownToPlainText(String text) {
      final robustText = _convertMarkdownToHtmlRobustly(text);
      final html = md.markdownToHtml(robustText, extensionSet: md.ExtensionSet.gitHubFlavored);
      return html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll('\uFFFD', "'");
    }

    // Title is the first paragraph
    String title = '';
    if (paragraphs.isNotEmpty) {
      title = cleanMarkdownToPlainText(paragraphs[0]);
    }
    if (title.isEmpty) {
      title = fallbackTitle;
    }

    // Author is the second paragraph
    String authorFullName = '';
    if (paragraphs.length > 1) {
      authorFullName = cleanMarkdownToPlainText(paragraphs[1]);
    }
    if (authorFullName.isEmpty || authorFullName.split(' ').length > 4 || authorFullName.toLowerCase().contains('abstract')) {
      authorFullName = fallbackCreator;
    }

    // Extract Abstract Paragraphs (Markdown)
    final abstractMarkdownParagraphs = <String>[];
    bool collectingAbstract = false;

    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      final lower = p.toLowerCase();

      final isAbstractHeader = lower == '## abstract' || lower == 'abstract' || lower == '**abstract**' || lower == '*abstract*';
      final startsWithAbstract = lower.startsWith('abstract:') || lower.startsWith('**abstract:**') || lower.startsWith('*abstract:*');

      if (isAbstractHeader || startsWithAbstract) {
        collectingAbstract = true;
        String content = p;
        if (startsWithAbstract) {
          content = p.replaceFirst(RegExp(r'^[\s#*_]*abstract[:\s#*_]*', caseSensitive: false), '');
        } else {
          continue;
        }
        if (content.trim().isNotEmpty) {
          abstractMarkdownParagraphs.add(content.trim());
        }
        continue;
      }

      if (collectingAbstract) {
        if (p.startsWith('#') || 
            lower.startsWith('keywords') || 
            lower.startsWith('**keywords') || 
            lower.startsWith('*keywords') ||
            lower == 'bibliography' ||
            lower == 'references' ||
            lower == '## bibliography' ||
            lower == '## references') {
          collectingAbstract = false;
        } else {
          abstractMarkdownParagraphs.add(p);
        }
      }
    }

    // Extract Keywords Paragraphs (Markdown)
    final keywordsMarkdownParagraphs = <String>[];
    bool collectingKeywords = false;

    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      final lower = p.toLowerCase();

      final isKeywordsHeader = lower == '## keywords' || lower == 'keywords' || lower == '**keywords**' || lower == '*keywords*';
      final startsWithKeywords = lower.startsWith('keywords:') || lower.startsWith('**keywords:**') || lower.startsWith('*keywords:*') || lower.startsWith('keywords ');

      if (isKeywordsHeader || startsWithKeywords) {
        collectingKeywords = true;
        String content = p;
        if (startsWithKeywords) {
          content = p.replaceFirst(RegExp(r'^[\s#*_]*keywords[:\s#*_]*', caseSensitive: false), '');
        } else {
          continue;
        }
        if (content.trim().isNotEmpty) {
          keywordsMarkdownParagraphs.add(content.trim());
        }
        continue;
      }

      if (collectingKeywords) {
        if (p.startsWith('#') || 
            lower == 'bibliography' ||
            lower == 'references' ||
            lower == '## bibliography' ||
            lower == '## references') {
          collectingKeywords = false;
        } else {
          keywordsMarkdownParagraphs.add(p);
        }
      }
    }

    // Clean plain text versions
    String cleanHtmlToPlainText(String html) {
      return html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAll('\uFFFD', "'");
    }

    // Build Abstract HTML
    final abstractHtmlList = <String>[];
    for (final p in abstractMarkdownParagraphs) {
      final robustP = _convertMarkdownToHtmlRobustly(p);
      final html = md.markdownToHtml(robustP, extensionSet: md.ExtensionSet.gitHubFlavored).trim();
      if (html.isNotEmpty) {
        abstractHtmlList.add(html);
      }
    }
    final abstractHtml = abstractHtmlList.join('\n');
    final abstractText = cleanHtmlToPlainText(abstractHtml);

    // Build Keywords HTML
    final keywordsHtmlList = <String>[];
    for (final p in keywordsMarkdownParagraphs) {
      final robustP = _convertMarkdownToHtmlRobustly(p);
      final html = md.markdownToHtml(robustP, extensionSet: md.ExtensionSet.gitHubFlavored).trim();
      if (html.isNotEmpty) {
        keywordsHtmlList.add(html);
      }
    }
    final keywordsHtml = keywordsHtmlList.join('\n');
    final keywords = cleanHtmlToPlainText(keywordsHtml);



    // Extract Author Bio and Affiliation
    String authorBio = '';
    String authorAffiliation = '';
    if (authorFullName.isNotEmpty) {
      final bioRegex = RegExp('[*_]*${RegExp.escape(authorFullName)}[*_]*\\s+is\\s+', caseSensitive: false);
      for (final p in paragraphs) {
        if (bioRegex.hasMatch(p)) {
           final robustP = _convertMarkdownToHtmlRobustly(p);
           final bioHtml = md.markdownToHtml(robustP, extensionSet: md.ExtensionSet.gitHubFlavored).trim();
           authorBio = bioHtml;
           if (authorBio.startsWith('<p>') && authorBio.endsWith('</p>')) {
             authorBio = authorBio.substring(3, authorBio.length - 4);
           }
           
           final affMatch = RegExp(
             r'at\s+(the\s+)?([^.]+University[^.]+|[^.]+Institute[^.]+|[^.]+College[^.]+)',
             caseSensitive: false,
           ).firstMatch(p);
           if (affMatch != null) {
             authorAffiliation = affMatch.group(2)!.trim();
           }
           break;
        }
      }
    }

    // Load images from ZIP
    final Map<String, String> imageBase64Map = {};
    for (final zipFile in archive.files) {
      if (zipFile.name.contains('media/') || zipFile.name.contains('image')) {
        final ext = zipFile.name.split('.').last.toLowerCase();
        if (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'gif' || ext == 'svg') {
          final mimeType = _getMimeType(ext);
          final base64String = base64Encode(zipFile.content);
          final dataUri = 'data:$mimeType;base64,$base64String';
          final basename = zipFile.name.split('/').last;
          imageBase64Map[basename] = dataUri;
          imageBase64Map[zipFile.name] = dataUri;
          if (zipFile.name.startsWith('word/')) {
            imageBase64Map[zipFile.name.substring(5)] = dataUri;
          }
        }
      }
    }

    // Image replacement helper
    String processImagesInHtml(String html) {
      String result = html;
      final srcRegex = RegExp(r'''src=["']([^"']+)["']''');
      result = result.replaceAllMapped(srcRegex, (match) {
        final src = match.group(1)!;
        final basename = src.split('/').last;
        if (imageBase64Map.containsKey(src)) {
          return 'src="${imageBase64Map[src]}"';
        } else if (imageBase64Map.containsKey(basename)) {
          return 'src="${imageBase64Map[basename]}"';
        }
        return match.group(0)!;
      });
      return result;
    }

    // Assemble the body HTML list
    final bodyHtmlList = <String>[];
    bool inAbstractSection = false;
    bool inKeywordsSection = false;
    
    for (final p in paragraphs) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      
      final lower = trimmed.toLowerCase();
      
      // Skip title
      if (trimmed == '# $title' || trimmed == title || cleanMarkdownToPlainText(trimmed) == title) {
        continue;
      }
      
      // Skip author full name line
      if (trimmed == authorFullName) {
        continue;
      }
      
      // Abstract check
      final isAbstractHeader = lower == '## abstract' || lower == 'abstract' || lower == '**abstract**' || lower == '*abstract*';
      final startsWithAbstract = lower.startsWith('abstract:') || lower.startsWith('**abstract:**') || lower.startsWith('*abstract:*');
      if (isAbstractHeader || startsWithAbstract) {
        inAbstractSection = true;
        inKeywordsSection = false;
        continue;
      }
      
      // Keywords check
      final isKeywordsHeader = lower == '## keywords' || lower == 'keywords' || lower == '**keywords**' || lower == '*keywords*';
      final startsWithKeywords = lower.startsWith('keywords:') || lower.startsWith('**keywords:**') || lower.startsWith('*keywords:*') || lower.startsWith('keywords ');
      if (isKeywordsHeader || startsWithKeywords) {
        inKeywordsSection = true;
        inAbstractSection = false;
        continue;
      }
      
      // If we are in abstract or keywords section, skip them from main body
      if (inAbstractSection) {
        if (trimmed.startsWith('#')) {
          inAbstractSection = false;
        } else {
          continue;
        }
      }
      if (inKeywordsSection) {
        if (trimmed.startsWith('#')) {
          inKeywordsSection = false;
        } else {
          continue;
        }
      }
      
      // Compile paragraph/element to HTML
      final preservedText = _preserveLineBreaks(trimmed);
      final robustP = _convertMarkdownToHtmlRobustly(preservedText);
      var html = md.markdownToHtml(robustP, extensionSet: md.ExtensionSet.gitHubFlavored).trim();
      if (html.isNotEmpty) {
        final plain = cleanHtmlToPlainText(html);
        if (RegExp(r'^Fig(ure|s|\.)?\s+\d+', caseSensitive: false).hasMatch(plain)) {
          html = html.replaceFirst('<p>', '<p style="font-size: 12px;">');
        }
        bodyHtmlList.add(processImagesInHtml(html));
      }
    }

    final consolidatedBody = bodyHtmlList.join('\n');

    // Build footnotes section
    final footnoteSectionBuffer = StringBuffer();
    if (footnotesMap.isNotEmpty) {
      footnoteSectionBuffer.writeln('<h2>Notes</h2>');
      final sortedIds = footnotesMap.keys.toList()
        ..sort((a, b) {
          final aInt = int.tryParse(a) ?? 0;
          final bInt = int.tryParse(b) ?? 0;
          return aInt.compareTo(bInt);
        });
      for (final id in sortedIds) {
        final html = footnotesMap[id]!;
        final cleanHtml = processImagesInHtml(html);
        footnoteSectionBuffer.writeln('<p id="fn$id"><sup><a href="#ref$id">$id</a></sup> $cleanHtml</p>');
      }
    }

    // Combine all sections into the final body
    final finalBody = StringBuffer();
    if (abstractHtml.isNotEmpty) {
      finalBody.writeln('<h2>Abstract</h2>');
      finalBody.writeln(abstractHtml);
    }
    if (keywordsHtml.isNotEmpty) {
      finalBody.writeln('<h2>Keywords</h2>');
      finalBody.writeln(keywordsHtml);
    }
    finalBody.writeln(consolidatedBody);



    if (footnoteSectionBuffer.isNotEmpty) {
      finalBody.writeln(footnoteSectionBuffer.toString());
    }

    String volume = '7';
    String issue = '1';

    final authorParts = authorFullName.trim().split(RegExp(r'\s+'));
    final authorFirstName = authorParts.isNotEmpty ? authorParts.first : '';
    final authorLastName = authorParts.length > 1 ? authorParts.last : '';
    final author = authorLastName.toUpperCase();

    return ArticleMetadata(
      title: title,
      author: author,
      authorFullName: authorFullName,
      authorFirstName: authorFirstName,
      authorLastName: authorLastName,
      keywords: keywords.trim(),
      articleAbstract: abstractText.trim(),
      articleBody: finalBody.toString(),
      authorOrcid: '',
      authorAffiliation: authorAffiliation,
      authorBio: authorBio,
      volume: volume,
      issue: issue,
      articleId: articleId,
      submissionId: articleId.isNotEmpty ? articleId : '',
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

  String _getMimeType(String ext) {
    switch (ext) {
      case 'png': return 'image/png';
      case 'jpeg':
      case 'jpg': return 'image/jpeg';
      case 'gif': return 'image/gif';
      case 'svg': return 'image/svg+xml';
      default: return 'image/jpeg';
    }
  }

  String _convertMarkdownToHtmlRobustly(String markdown) {
    if (markdown.isEmpty) return markdown;
    
    // Clean redundant markdown markers first
    final clean = cleanRedundantMarkdownMarkers(markdown);
    String result = clean;
    
    // 1. Process Bold (Double Asterisks/Underscores): ** or __
    result = _replacePairs(result, '**', '<strong>', '</strong>');
    result = _replacePairs(result, '__', '<strong>', '</strong>');
    
    // 2. Process Italics (Single Asterisks/Underscores): * or _
    result = _replacePairs(result, '*', '<em>', '</em>');
    result = _replacePairs(result, '_', '<em>', '</em>');
    
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

  String _preserveLineBreaks(String text) {
    return text;
  }

  String _formatMonYYYY(DateTime date) {
    final months = [
      'Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'June',
      'July', 'Aug.', 'Sept.', 'Oct.', 'Nov.', 'Dec.',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _mergeAdjacentRuns(XmlDocument document) {
    for (final p in document.findAllElements('w:p')) {
      final runs = p.findElements('w:r').toList();
      if (runs.length < 2) continue;
      
      int i = 0;
      while (i < runs.length - 1) {
        final current = runs[i];
        final next = runs[i + 1];
        
        final pChildren = p.children.toList();
        final currentIdx = pChildren.indexOf(current);
        final nextIdx = pChildren.indexOf(next);
        if (nextIdx != currentIdx + 1) {
          i++;
          continue;
        }
        
        final pr1 = current.findElements('w:rPr').firstOrNull;
        final pr2 = next.findElements('w:rPr').firstOrNull;
        
        final otherElements1 = current.children.whereType<XmlElement>().where((e) => e.name.local != 'rPr' && e.name.local != 't');
        final otherElements2 = next.children.whereType<XmlElement>().where((e) => e.name.local != 'rPr' && e.name.local != 't');
        
        if (otherElements1.isEmpty && otherElements2.isEmpty && _arePropertiesIdentical(pr1, pr2)) {
          final t1 = current.findElements('w:t').firstOrNull;
          final t2 = next.findElements('w:t').firstOrNull;
          
          if (t1 != null && t2 != null) {
            final space1 = t1.getAttribute('xml:space');
            final space2 = t2.getAttribute('xml:space');
            if (space1 == 'preserve' || space2 == 'preserve' || t2.innerText.startsWith(' ') || t1.innerText.endsWith(' ')) {
              t1.setAttribute('xml:space', 'preserve');
            }
            
            t1.innerText = t1.innerText + t2.innerText;
            next.parent?.children.remove(next);
            runs.removeAt(i + 1);
            continue;
          }
        }
        i++;
      }
    }
  }

  bool _isBold(XmlElement? rPr) {
    if (rPr == null) return false;
    final b = rPr.findElements('w:b').firstOrNull;
    final bCs = rPr.findElements('w:bCs').firstOrNull;
    bool hasBold = false;
    if (b != null) {
      final val = b.getAttribute('w:val');
      if (val != 'false' && val != '0' && val != 'none' && val != 'off') {
        hasBold = true;
      } else if (val == null) {
        hasBold = true;
      }
    }
    if (bCs != null) {
      final val = bCs.getAttribute('w:val');
      if (val != 'false' && val != '0' && val != 'none' && val != 'off') {
        hasBold = true;
      } else if (val == null) {
        hasBold = true;
      }
    }
    return hasBold;
  }

  bool _isItalic(XmlElement? rPr) {
    if (rPr == null) return false;
    final i = rPr.findElements('w:i').firstOrNull;
    final iCs = rPr.findElements('w:iCs').firstOrNull;
    bool hasItalic = false;
    if (i != null) {
      final val = i.getAttribute('w:val');
      if (val != 'false' && val != '0' && val != 'none' && val != 'off') {
        hasItalic = true;
      } else if (val == null) {
        hasItalic = true;
      }
    }
    if (iCs != null) {
      final val = iCs.getAttribute('w:val');
      if (val != 'false' && val != '0' && val != 'none' && val != 'off') {
        hasItalic = true;
      } else if (val == null) {
        hasItalic = true;
      }
    }
    return hasItalic;
  }

  bool _arePropertiesIdentical(XmlElement? pr1, XmlElement? pr2) {
    return _isBold(pr1) == _isBold(pr2) && _isItalic(pr1) == _isItalic(pr2);
  }
}

class _Span {
  final String text;
  final bool bold;
  final bool italic;
  _Span(this.text, this.bold, this.italic);
}

String cleanRedundantMarkdownMarkers(String text) {
  int index = 0;
  bool bold = false;
  bool italic = false;
  
  final spans = <_Span>[];
  final currentText = StringBuffer();
  
  void flushText() {
    if (currentText.isNotEmpty) {
      spans.add(_Span(currentText.toString(), bold, italic));
      currentText.clear();
    }
  }
  
  while (index < text.length) {
    if (text.startsWith('***', index) || text.startsWith('___', index)) {
      flushText();
      bold = !bold;
      italic = !italic;
      index += 3;
    } else if (text.startsWith('**', index) || text.startsWith('__', index)) {
      flushText();
      bold = !bold;
      index += 2;
    } else if (text.startsWith('*', index) || text.startsWith('_', index)) {
      flushText();
      italic = !italic;
      index += 1;
    } else {
      currentText.write(text[index]);
      index++;
    }
  }
  flushText();
  
  final mergedSpans = <_Span>[];
  for (final span in spans) {
    if (mergedSpans.isEmpty) {
      mergedSpans.add(span);
    } else {
      final last = mergedSpans.last;
      if (last.bold == span.bold && last.italic == span.italic) {
        mergedSpans[mergedSpans.length - 1] = _Span(last.text + span.text, last.bold, last.italic);
      } else {
        mergedSpans.add(span);
      }
    }
  }
  
  final buffer = StringBuffer();
  bool currentBold = false;
  bool currentItalic = false;
  
  for (final span in mergedSpans) {
    final needBold = span.bold;
    final needItalic = span.italic;
    
    if (currentBold != needBold && currentItalic != needItalic) {
      buffer.write('***');
      currentBold = needBold;
      currentItalic = needItalic;
    } else if (currentBold != needBold) {
      buffer.write('**');
      currentBold = needBold;
    } else if (currentItalic != needItalic) {
      buffer.write('*');
      currentItalic = needItalic;
    }
    
    buffer.write(span.text);
  }
  
  if (currentBold && currentItalic) {
    buffer.write('***');
  } else if (currentBold) {
    buffer.write('**');
  } else if (currentItalic) {
    buffer.write('*');
  }
  
  return buffer.toString();
}

