import 'dart:io';
import 'dart:convert';
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

    // Convert DOCX to Markdown
    final converter = DocxConverter(bytes);
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
      return '<sup><a href="#fn$id" id="ref$id">$id</a></sup>';
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

    // Extract Bibliography section
    int bibIndex = -1;
    final bibParagraphsHtml = <String>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      final lower = p.toLowerCase();
      if (lower == '## bibliography' || lower == 'bibliography' || lower == '## references' || lower == 'references' || lower == '**bibliography**' || lower == '**references**') {
        bibIndex = i;
        break;
      }
    }

    if (bibIndex != -1) {
      for (int j = bibIndex + 1; j < paragraphs.length; j++) {
        final p = paragraphs[j];
        if (p.isEmpty) continue;
        if (p.startsWith('#')) break;
        final robustP = _convertMarkdownToHtmlRobustly(p);
        final html = md.markdownToHtml(robustP, extensionSet: md.ExtensionSet.gitHubFlavored).trim();
        if (html.startsWith('<p>') && html.endsWith('</p>')) {
          final inner = html.substring(3, html.length - 4);
          bibParagraphsHtml.add('<div class="csl-entry">$inner</div>');
        } else {
          bibParagraphsHtml.add('<div class="csl-entry">$html</div>');
        }
      }
    }

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
    bool inBibliographySection = false;
    
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
        inBibliographySection = false;
        continue;
      }
      
      // Keywords check
      final isKeywordsHeader = lower == '## keywords' || lower == 'keywords' || lower == '**keywords**' || lower == '*keywords*';
      final startsWithKeywords = lower.startsWith('keywords:') || lower.startsWith('**keywords:**') || lower.startsWith('*keywords:*') || lower.startsWith('keywords ');
      if (isKeywordsHeader || startsWithKeywords) {
        inKeywordsSection = true;
        inAbstractSection = false;
        inBibliographySection = false;
        continue;
      }
      
      // Bibliography check
      if (lower == '## bibliography' || lower == 'bibliography' || lower == '## references' || lower == 'references' || lower == '**bibliography**' || lower == '**references**') {
        inBibliographySection = true;
        inAbstractSection = false;
        inKeywordsSection = false;
        continue;
      }
      
      // If we are in abstract, keywords, or bibliography section, skip them from main body
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
      if (inBibliographySection) {
        continue;
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
      footnotesMap.forEach((id, html) {
        final cleanHtml = processImagesInHtml(html);
        footnoteSectionBuffer.writeln('<p id="fn$id">$cleanHtml <a href="#ref$id">↩</a></p>');
      });
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

    
    if (bibParagraphsHtml.isNotEmpty) {
      finalBody.writeln('<h2>Bibliography</h2>');
      for (final bibHtml in bibParagraphsHtml) {
        finalBody.writeln(processImagesInHtml(bibHtml));
      }
    }

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
    
    String result = markdown;
    
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
}
