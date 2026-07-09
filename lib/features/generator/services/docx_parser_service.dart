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

    // Extract basic metadata: DOI -> articleId, volume, issue from footer/header
    String articleId = '';
    String volume = '';
    String issue = '';
    for (final zipFile in archive.files) {
      if (zipFile.name.startsWith('word/footer') || zipFile.name.startsWith('word/header')) {
        try {
          final xmlStr = utf8.decode(zipFile.content);
          final plainText = xmlStr.replaceAll(RegExp(r'<[^>]*>'), '');
          
          final volMatch = RegExp(r'Volume\s*(\d+)', caseSensitive: false).firstMatch(plainText);
          final issMatch = RegExp(r'Issue\s*(\d+)', caseSensitive: false).firstMatch(plainText);
          if (volMatch != null) {
            volume = volMatch.group(1)!;
          }
          if (issMatch != null) {
            issue = issMatch.group(1)!;
          }

          if (plainText.contains('doi.org')) {
             final doiMatch = RegExp(r'(?:https?://)?doi\.org/[^\s<>"]+').firstMatch(plainText);
             if (doiMatch != null) {
               String doiUrl = doiMatch.group(0)!;
               doiUrl = doiUrl.replaceAll(RegExp(r'[./,;]+$'), '');
               
               final doiRegex = RegExp(r'v(\d+)i(\d+)\.(\d+)');
               final match = doiRegex.firstMatch(doiUrl);
               if (match != null) {
                 volume = match.group(1)!;
                 issue = match.group(2)!;
                 articleId = match.group(3)!;
               } else {
                 final parts = doiUrl.split('.');
                 if (parts.isNotEmpty) {
                   final lastPart = parts.last;
                   if (RegExp(r'^\d+$').hasMatch(lastPart)) {
                     articleId = lastPart;
                   }
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
          _cleanParagraphBorders(document);
          _tagIndentedParagraphs(document);
          
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
    var cleanMarkdown = markdown.replaceAll(RegExp(r'''<a\s+id=["'][\w\d]+["']>\s*</a>'''), '');
    cleanMarkdown = _cleanMarkdownLinks(cleanMarkdown);

    // 1.5. Clean image alt texts: remove newlines and AI disclaimers from markdown image alt texts before paragraph splitting
    cleanMarkdown = cleanMarkdown.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
      (match) {
        var altText = match.group(1)!;
        final imageUrl = match.group(2)!;
        
        // Remove known AI-generated content disclaimers
        altText = altText.replaceAll(RegExp(r'\bAI-generated content may be incorrect\.?', caseSensitive: false), '');
        altText = altText.replaceAll(RegExp(r'\bDescription automatically generated\.?', caseSensitive: false), '');
        
        // Clean up newlines, carriage returns, and excess whitespace
        altText = altText.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        
        return '![$altText]($imageUrl)';
      },
    );

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
      return '<sup id="ref$id"><a href="#fn$id">[$id]</a></sup>';
    });

    // Split remaining content into paragraphs
    final paragraphs = cleanMarkdown.split(RegExp(r'\n\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // Helpers
    String cleanMarkdownToPlainText(String text) {
      final robustText = _convertMarkdownToHtmlRobustly(text);
      final html = md.markdownToHtml(robustText, extensionSet: md.ExtensionSet.gitHubFlavored);
      return html
          .replaceAll(RegExp(r'\[:indent:[^\]]+\]'), '')
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAll('\uFFFD', "'");
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
      final indentMatch = RegExp(r'\[:indent:[^\]]+\]').firstMatch(p);
      final indentMarker = indentMatch?.group(0) ?? '';
      final cleanP = p.replaceAll(RegExp(r'\[:indent:[^\]]+\]'), '');
      final lower = cleanP.toLowerCase();

      final isAbstractHeader = lower == '## abstract' || lower == 'abstract' || lower == '**abstract**' || lower == '*abstract*';
      final startsWithAbstract = lower.startsWith('abstract:') || lower.startsWith('**abstract:**') || lower.startsWith('*abstract:*');

      if (isAbstractHeader || startsWithAbstract) {
        collectingAbstract = true;
        String content = cleanP;
        if (startsWithAbstract) {
          content = cleanP.replaceFirst(RegExp(r'^[\s#*_]*abstract[:\s#*_]*', caseSensitive: false), '');
        } else {
          continue;
        }
        if (content.trim().isNotEmpty) {
          abstractMarkdownParagraphs.add(indentMarker + content.trim());
        }
        continue;
      }

      if (collectingAbstract) {
        if (cleanP.startsWith('#') || 
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
      final indentMatch = RegExp(r'\[:indent:[^\]]+\]').firstMatch(p);
      final indentMarker = indentMatch?.group(0) ?? '';
      final cleanP = p.replaceAll(RegExp(r'\[:indent:[^\]]+\]'), '');
      final lower = cleanP.toLowerCase();

      final isKeywordsHeader = lower == '## keywords' || lower == 'keywords' || lower == '**keywords**' || lower == '*keywords*';
      final startsWithKeywords = lower.startsWith('keywords:') || lower.startsWith('**keywords:**') || lower.startsWith('*keywords:*') || lower.startsWith('keywords ');

      if (isKeywordsHeader || startsWithKeywords) {
        collectingKeywords = true;
        String content = cleanP;
        if (startsWithKeywords) {
          content = cleanP.replaceFirst(RegExp(r'^[\s#*_]*keywords[:\s#*_]*', caseSensitive: false), '');
        } else {
          continue;
        }
        if (content.trim().isNotEmpty) {
          keywordsMarkdownParagraphs.add(indentMarker + content.trim());
          collectingKeywords = false;
        }
        continue;
      }

      if (collectingKeywords) {
        if (cleanP.startsWith('#') || 
            lower == 'bibliography' ||
            lower == 'references' ||
            lower == '## bibliography' ||
            lower == '## references') {
          collectingKeywords = false;
        } else {
          keywordsMarkdownParagraphs.add(p);
          collectingKeywords = false;
        }
      }
    }

    // Clean plain text versions
    String cleanHtmlToPlainText(String html) {
      return html
          .replaceAll(RegExp(r'\[:indent:[^\]]+\]'), '')
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
        abstractHtmlList.add(_processIndentation(html));
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
        keywordsHtmlList.add(_processIndentation(html));
      }
    }
    final keywordsHtml = keywordsHtmlList.join('\n');
    final keywords = cleanHtmlToPlainText(keywordsHtml);



    // Extract Author Bio and Affiliation
    String authorBio = '';
    String authorAffiliation = '';
    if (authorFullName.isNotEmpty) {
      final authorParts = authorFullName.trim().split(RegExp(r'\s+'));
      final authorFirstName = authorParts.isNotEmpty ? authorParts.first : '';
      final authorLastName = authorParts.length > 1 ? authorParts.last : '';
      
      final escapedFullName = RegExp.escape(authorFullName);
      final escapedFirstLast = authorLastName.isNotEmpty 
          ? '${RegExp.escape(authorFirstName)}\\s+${RegExp.escape(authorLastName)}'
          : '';
      
      final bioPatterns = [
        '[^\\w]*$escapedFullName[\\s*_]+is\\b',
        if (escapedFirstLast.isNotEmpty) '[\\s*_]*$escapedFirstLast[\\s*_]+is\\b',
      ];
      
      final bioRegex = RegExp(bioPatterns.join('|'), caseSensitive: false);
      for (final p in paragraphs) {
        if (bioRegex.hasMatch(p)) {
           final robustP = _convertMarkdownToHtmlRobustly(p);
           final bioHtml = md.markdownToHtml(robustP, extensionSet: md.ExtensionSet.gitHubFlavored).trim();
           authorBio = bioHtml.replaceAll(RegExp(r'\[:indent:[^\]]+\]'), '');
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
      
      final cleanTrimmed = trimmed.replaceAll(RegExp(r'\[:indent:[^\]]+\]'), '');
      final lower = cleanTrimmed.toLowerCase();
      
      // Skip title
      if (cleanTrimmed == '# $title' || cleanTrimmed == title || cleanMarkdownToPlainText(trimmed) == title) {
        continue;
      }
      
      // Skip author full name line
      if (cleanTrimmed == authorFullName) {
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
        if (startsWithKeywords) {
          final content = cleanTrimmed.replaceFirst(RegExp(r'^[\s#*_]*keywords[:\s#*_]*', caseSensitive: false), '');
          if (content.trim().isNotEmpty) {
            inKeywordsSection = false;
          }
        }
        continue;
      }
      
      // If we are in abstract or keywords section, skip them from main body
      if (inAbstractSection) {
        if (cleanTrimmed.startsWith('#')) {
          inAbstractSection = false;
        } else {
          continue;
        }
      }
      if (inKeywordsSection) {
        if (cleanTrimmed.startsWith('#')) {
          inKeywordsSection = false;
        } else {
          inKeywordsSection = false;
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
        html = _processIndentation(html);
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
        final footnoteParagraph = '<p id="fn$id"><a href="#ref$id">[$id]</a> $cleanHtml</p>';
        footnoteSectionBuffer.writeln(_processIndentation(footnoteParagraph));
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

    // volume and issue are extracted from footer/header above

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
    
    // Replace markdown links, images, and HTML tags with placeholders to avoid corrupting them.
    final placeholders = <String>[];
    final regex = RegExp(r'(!?\[[^\]]*\]\([^)]*\)|<[^>]+>)');
    
    final temp = markdown.replaceAllMapped(regex, (match) {
      final matchedText = match.group(0)!;
      final placeholder = '@@@PLACEHOLDER${placeholders.length}@@@';
      placeholders.add(matchedText);
      return placeholder;
    });

    // Clean redundant markdown markers first
    final clean = cleanRedundantMarkdownMarkers(temp);
    String result = clean;
    
    // 1. Process Bold (Double Asterisks/Underscores): ** or __
    result = _replacePairs(result, '**', '<strong>', '</strong>');
    result = _replacePairs(result, '__', '<strong>', '</strong>');
    
    // 2. Process Italics (Single Asterisks/Underscores): * or _
    result = _replacePairs(result, '*', '<em>', '</em>');
    result = _replacePairs(result, '_', '<em>', '</em>');
    
    // Restore placeholders
    for (int i = 0; i < placeholders.length; i++) {
      result = result.replaceAll('@@@PLACEHOLDER${i}@@@', placeholders[i]);
    }
    
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _cleanMarkdownLinks(String markdown) {
    // Regex matches [linkText](linkUrl)
    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    return markdown.replaceAllMapped(linkRegex, (match) {
      var text = match.group(1)!;
      var url = match.group(2)!;

      // 1. Clean up escaped or unescaped HTML underline/formatting tags in the text
      text = text.replaceAll(RegExp(r'\\?<u\\?>', caseSensitive: false), '');
      text = text.replaceAll(RegExp(r'\\?</u\\?>', caseSensitive: false), '');
      text = text.replaceAll(RegExp(r'\\?&lt;u\\?&gt;', caseSensitive: false), '');
      text = text.replaceAll(RegExp(r'\\?&lt;/u\\?&gt;', caseSensitive: false), '');

      // 2. Remove backslashes escaping underscores or other characters in the link text
      text = text.replaceAllMapped(RegExp(r'\\+([_*#\\])'), (m) => m.group(1)!);
      text = text.replaceAll(RegExp(r'\\+$'), ''); // Clean up trailing backslashes
      text = text.trim();

      // 3. Remove backslashes escaping characters in the URL
      url = url.replaceAllMapped(RegExp(r'\\+([_*#\\])'), (m) => m.group(1)!);
      url = url.replaceAll(RegExp(r'\\+$'), '');
      url = url.trim();

      // 4. If the link text is a full URL (http, https, mailto, doi.org) but the URL was truncated
      // to just a fragment/anchor because of a '#' symbol (e.g. webpage: [url](#/index)), restore the full URL.
      if ((text.startsWith('http://') || text.startsWith('https://') || text.startsWith('www.')) &&
          (url.startsWith('#') || !url.contains('://'))) {
        url = text;
      }

      return '[$text]($url)';
    });
  }

  void _cleanParagraphBorders(XmlDocument document) {
    for (final p in document.findAllElements('w:p')) {
      final pPr = p.findElements('w:pPr').firstOrNull;
      if (pPr == null) continue;
      final pBdr = pPr.findElements('w:pBdr').firstOrNull;
      if (pBdr == null) continue;

      // Case 1: The paragraph contains drawings or pictures
      final hasImages = p.findAllElements('w:drawing').isNotEmpty || p.findAllElements('w:pict').isNotEmpty;
      if (hasImages) {
        pBdr.parent?.children.remove(pBdr);
        continue;
      }

      // Case 2: Remove bottom/top borders if they are nil
      final bottom = pBdr.findElements('w:bottom').firstOrNull;
      if (bottom != null && bottom.getAttribute('w:val') == 'nil') {
        pBdr.children.remove(bottom);
      }
      final top = pBdr.findElements('w:top').firstOrNull;
      if (top != null && top.getAttribute('w:val') == 'nil') {
        pBdr.children.remove(top);
      }

      // If pBdr has no children left of type XmlElement, remove it entirely
      if (pBdr.children.whereType<XmlElement>().isEmpty) {
        pBdr.parent?.children.remove(pBdr);
      }
    }
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

  void _tagIndentedParagraphs(XmlDocument document) {
    for (final p in document.findAllElements('w:p')) {
      final pPr = p.findElements('w:pPr').firstOrNull;
      if (pPr == null) continue;
      final ind = pPr.findElements('w:ind').firstOrNull;
      if (ind == null) continue;

      final leftAttr = ind.getAttribute('w:left') ?? ind.getAttribute('w:start');
      final rightAttr = ind.getAttribute('w:right') ?? ind.getAttribute('w:end');
      final firstLineAttr = ind.getAttribute('w:firstLine');
      final hangingAttr = ind.getAttribute('w:hanging');

      final left = int.tryParse(leftAttr ?? '') ?? 0;
      final right = int.tryParse(rightAttr ?? '') ?? 0;
      final firstLine = int.tryParse(firstLineAttr ?? '') ?? 0;
      final hanging = int.tryParse(hangingAttr ?? '') ?? 0;

      if (left == 0 && right == 0 && firstLine == 0 && hanging == 0) continue;

      final t = p.findAllElements('w:t').firstOrNull;
      if (t != null) {
        final marker = '[:indent:left=$left,right=$right,firstLine=$firstLine,hanging=$hanging:]';
        t.innerText = marker + t.innerText;
      }
    }
  }

  String _processIndentation(String html) {
    final indentRegex = RegExp(r'\[:indent:([^\]]+)\]');
    final match = indentRegex.firstMatch(html);
    if (match == null) return html;

    final marker = match.group(0)!;
    final attrsStr = match.group(1)!;

    int left = 0;
    int right = 0;
    int firstLine = 0;
    int hanging = 0;

    final parts = attrsStr.split(',');
    for (final part in parts) {
      final kv = part.split('=');
      if (kv.length == 2) {
        final key = kv[0].trim();
        final val = int.tryParse(kv[1].trim()) ?? 0;
        if (key == 'left') left = val;
        if (key == 'right') right = val;
        if (key == 'firstLine') firstLine = val;
        if (key == 'hanging') hanging = val;
      }
    }

    var cleanHtml = html.replaceFirst(marker, '');

    final styles = <String>[];
    if (left > 0) {
      styles.add('margin-left: ${(left / 20).toStringAsFixed(1)}pt');
    }
    if (right > 0) {
      styles.add('margin-right: ${(right / 20).toStringAsFixed(1)}pt');
    }
    if (firstLine > 0) {
      styles.add('text-indent: ${(firstLine / 20).toStringAsFixed(1)}pt');
    }
    if (hanging > 0) {
      styles.add('text-indent: -${(hanging / 20).toStringAsFixed(1)}pt');
      final totalLeft = left + hanging;
      styles.removeWhere((s) => s.startsWith('margin-left:'));
      styles.add('margin-left: ${(totalLeft / 20).toStringAsFixed(1)}pt');
    }

    if (styles.isEmpty) return cleanHtml;

    final styleContent = styles.join('; ') + ';';

    final cleanTrimmed = cleanHtml.trimLeft();
    final tagRegex = RegExp(r'^<([a-zA-Z0-9]+)([^>]*)>');
    final tagMatch = tagRegex.firstMatch(cleanTrimmed);
    if (tagMatch != null) {
      var tagName = tagMatch.group(1)!;
      var tagAttrs = tagMatch.group(2)!;

      bool isConvertedToBlockquote = false;
      if (tagName == 'p' && (left > 0 || hanging > 0)) {
        tagName = 'blockquote';
        isConvertedToBlockquote = true;
      }

      if (tagAttrs.contains('style="')) {
        tagAttrs = tagAttrs.replaceFirstMapped(
          RegExp(r'style="([^"]*)"'),
          (m) {
            final existing = m.group(1)!.trim();
            final sep = (existing.isEmpty || existing.endsWith(';')) ? '' : ';';
            return 'style="$existing$sep $styleContent"';
          },
        );
      } else {
        tagAttrs = '$tagAttrs style="$styleContent"';
      }

      final leadingSpaceCount = cleanHtml.length - cleanTrimmed.length;
      final leadingSpace = cleanHtml.substring(0, leadingSpaceCount);

      var contentAndEnd = cleanTrimmed.substring(tagMatch.end);
      if (isConvertedToBlockquote) {
        final lastCloseP = contentAndEnd.lastIndexOf('</p>');
        if (lastCloseP != -1) {
          contentAndEnd = contentAndEnd.substring(0, lastCloseP) + '</blockquote>' + contentAndEnd.substring(lastCloseP + 4);
        }
      }

      cleanHtml = leadingSpace + '<$tagName$tagAttrs>' + contentAndEnd;
    }

    return cleanHtml;
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

