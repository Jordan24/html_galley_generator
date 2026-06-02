import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/article_metadata.dart';

class DocxParserService {
  Future<ArticleMetadata> parse(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Read relevant XML files
    final documentXmlFile = archive.findFile('word/document.xml');
    final documentRelsFile = archive.findFile('word/_rels/document.xml.rels');
    final footnotesXmlFile = archive.findFile('word/footnotes.xml');

    if (documentXmlFile == null) {
      throw Exception('Not a valid DOCX file (missing word/document.xml)');
    }

    final documentXml = XmlDocument.parse(utf8.decode(documentXmlFile.content));
    final documentRels = documentRelsFile != null
        ? XmlDocument.parse(utf8.decode(documentRelsFile.content))
        : null;
    final footnotesXml = footnotesXmlFile != null
        ? XmlDocument.parse(utf8.decode(footnotesXmlFile.content))
        : null;

    // Load relationships (Hyperlinks and Images)
    final Map<String, _Relationship> rels = {};
    if (documentRels != null) {
      for (final relNode in documentRels.findAllElements('Relationship')) {
        final id = relNode.getAttribute('Id');
        final target = relNode.getAttribute('Target');
        final type = relNode.getAttribute('Type');
        if (id != null && target != null && type != null) {
          rels[id] = _Relationship(target: target, type: type);
        }
      }
    }

    // Process Images
    final Map<String, String> imageBase64Map = {};
    rels.forEach((id, rel) {
      if (rel.type.endsWith('image')) {
        // Target is something like "media/image1.png"
        final imagePath = 'word/${rel.target}';
        final imageFile = archive.findFile(imagePath);
        if (imageFile != null) {
          final ext = rel.target.split('.').last.toLowerCase();
          final mimeType = _getMimeType(ext);
          final base64String = base64Encode(imageFile.content);
          imageBase64Map[id] = 'data:$mimeType;base64,$base64String';
        }
      }
    });

    // Process Footnotes
    final Map<String, String> footnotesMap = {};
    if (footnotesXml != null) {
      for (final footnoteNode in footnotesXml.findAllElements('w:footnote')) {
        final id = footnoteNode.getAttribute('w:id');
        if (id != null && id != '-1' && id != '0') { // -1 and 0 are usually separators
          final footnoteHtml = _processParagraphs(
            footnoteNode.findAllElements('w:p').toList(),
            rels,
            imageBase64Map,
            footnotesMap,
            isFootnoteContext: true,
          );
          footnotesMap[id] = footnoteHtml.trim();
        }
      }
    }

    // Extract basic metadata (can read from docProps/core.xml if needed)
    String title = '';
    String authorFullName = '';
    String authorBio = '';
    String authorAffiliation = '';
    String articleId = '';
    
    // Check footers and headers for DOI to get articleId
    for (final file in archive.files) {
      if (file.name.startsWith('word/footer') || file.name.startsWith('word/header')) {
        try {
          final xmlStr = utf8.decode(file.content);
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
    
    // Process Main Document Body
    final paragraphs = documentXml.findAllElements('w:p').toList();

    // First pass to extract title and author directly from document structure
    for (final p in paragraphs) {
      final text = _extractTextFromParagraph(p);
      if (text.trim().isEmpty) continue;
      
      if (title.isEmpty && _isHeading1(p)) {
        title = text.trim();
      }
      
      if (authorFullName.isEmpty) {
        final pStyle = p.findAllElements('w:pStyle').firstOrNull;
        final val = pStyle?.getAttribute('w:val');
        if (val == 'AuthorByline') {
          authorFullName = text.trim();
        }
      }
      
      if (title.isNotEmpty && authorFullName.isNotEmpty) break;
    }

    // Core properties fallback (only use if not found in document)
    if (title.isEmpty || authorFullName.isEmpty) {
      final coreXmlFile = archive.findFile('docProps/core.xml');
      if (coreXmlFile != null) {
         try {
           final coreXml = XmlDocument.parse(utf8.decode(coreXmlFile.content));
           final titleNode = coreXml.findAllElements('dc:title').firstOrNull;
           if (title.isEmpty && titleNode != null) title = titleNode.innerText.trim();
           final creatorNode = coreXml.findAllElements('dc:creator').firstOrNull;
           if (authorFullName.isEmpty && creatorNode != null) authorFullName = creatorNode.innerText.trim();
         } catch (_) {}
      }
    }
    
    String abstractText = '';
    String keywords = '';
    String volume = '7';
    String issue = '1';
    
    final consolidatedBody = StringBuffer();
    final footnoteSectionBuffer = StringBuffer();
    
    bool isAbstract = false;
    bool isKeywords = false;
    bool isReferences = false;

    // Extract Bio and Affiliation
    if (authorFullName.isNotEmpty) {
       final bioRegex = RegExp('${RegExp.escape(authorFullName)}\\s+is\\s+');
       for (final p in paragraphs) {
          final text = _extractTextFromParagraph(p).replaceAll('\u00A0', ' ').trim();
          if (bioRegex.hasMatch(text)) {
             authorBio = text;
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

    // Second pass to process content
    for (final p in paragraphs) {
      final text = _extractTextFromParagraph(p).trim();
      if (text.isEmpty) {
          // Check for images even if text is empty
          final html = _processSingleParagraph(p, rels, imageBase64Map, footnotesMap);
          if (html.isNotEmpty) {
             consolidatedBody.writeln(html);
          }
          continue;
      }

      final lowerText = text.toLowerCase();
      
      // Section Headers Detection
      final isExplicitHeader = RegExp(
        r'^(\d+\.?\s*)?(Introduction|Conclusion|Discussion|Results|Methods|Background|Bibliography|References|Notes|Footnotes|About the Author|Acknowledgements)',
        caseSensitive: false,
      ).hasMatch(text) && _isHeading(p);

      if (isExplicitHeader) {
         isAbstract = false;
         isKeywords = false;
      }

      if (lowerText == 'abstract' || lowerText.startsWith('abstract:')) {
        isAbstract = true;
        isKeywords = false;
        isReferences = false;
        if (lowerText.startsWith('abstract:')) {
          final content = text.substring(text.indexOf(':') + 1).trim();
          if (content.isNotEmpty) abstractText = content;
        }
        continue;
      } else if (lowerText == 'keywords' || lowerText.startsWith('keywords:') || lowerText.startsWith('keywords ')) {
        isKeywords = true;
        isAbstract = false;
        isReferences = false;
        if (lowerText.startsWith('keywords:') || lowerText.startsWith('keywords ')) {
          final splitIndex = text.indexOf(':');
          final content = splitIndex != -1 ? text.substring(splitIndex + 1).trim() : text.substring(8).trim();
          if (content.isNotEmpty) keywords = content;
        }
        continue;
      } else if (lowerText == 'bibliography' || lowerText == 'references') {
        isReferences = true;
        isAbstract = false;
        isKeywords = false;
        consolidatedBody.writeln('<h2>Bibliography</h2>');
        continue;
      } else if (lowerText == 'footnotes' || lowerText == 'notes') {
        isAbstract = false;
        isKeywords = false;
        isReferences = false;
        continue; // We will generate footnotes from the XML, not plain text usually
      }

      // If it's a section content
      if (isAbstract) {
         abstractText += ' $text';
      } else if (isKeywords) {
         if (keywords.isNotEmpty && !keywords.trim().endsWith(',')) keywords += ', ';
         keywords += text;
      } else {
         // Process the paragraph normally
         if (text == title && _isHeading1(p)) {
             // Skip writing the main title into the body
             continue;
         }
         final pStyle = p.findAllElements('w:pStyle').firstOrNull;
         final val = pStyle?.getAttribute('w:val');
         if (val == 'AuthorByline' || (authorFullName.isNotEmpty && text == authorFullName)) {
             // Skip writing the author name into the body
             continue;
         }
         
         String htmlContent = _processSingleParagraph(p, rels, imageBase64Map, footnotesMap);
         if (htmlContent.isNotEmpty) {
           if (isReferences) {
              consolidatedBody.writeln('<div class="csl-entry">$htmlContent</div>');
           } else {
              consolidatedBody.writeln(htmlContent);
           }
         }
      }
    }

    // Append Notes section if we found any footnote references
    if (footnotesMap.isNotEmpty) {
        footnoteSectionBuffer.writeln('<h2>Notes</h2>');
        // We need to keep track of which footnotes were actually used to output them in order
        // For simplicity, we can just iterate over the map keys as they are typically ordered
        footnotesMap.forEach((id, html) {
             footnoteSectionBuffer.writeln('<p id="fn$id">$html <a href="#ref$id">↩</a></p>');
        });
    }

    // Combine sections
    final finalBody = StringBuffer();
    if (abstractText.isNotEmpty) {
      finalBody.writeln('<h2>Abstract</h2>');
      finalBody.writeln('<p>${abstractText.trim()}</p>');
    }
    if (keywords.isNotEmpty) {
      finalBody.writeln('<h2>Keywords</h2>');
      finalBody.writeln('<p>${keywords.trim()}</p>');
    }
    finalBody.writeln(consolidatedBody.toString());
    if (footnoteSectionBuffer.isNotEmpty) {
      finalBody.writeln(footnoteSectionBuffer.toString());
    }

    return ArticleMetadata(
      title: title,
      author: authorFullName.split(' ').last.toUpperCase(),
      authorFullName: authorFullName,
      authorFirstName: authorFullName.isNotEmpty ? authorFullName.split(' ').first : '',
      authorLastName: authorFullName.isNotEmpty ? authorFullName.split(' ').last : '',
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

  bool _isHeading1(XmlElement p) {
    final pStyle = p.findAllElements('w:pStyle').firstOrNull;
    final val = pStyle?.getAttribute('w:val');
    return val == 'Heading1' || val == 'heading 1' || val == 'ArticleTitle' || val == 'Title';
  }

  bool _isHeading(XmlElement p) {
    final pStyle = p.findAllElements('w:pStyle').firstOrNull;
    final val = pStyle?.getAttribute('w:val') ?? '';
    return val.startsWith('Heading') || val.toLowerCase().startsWith('heading');
  }

  String _extractTextFromParagraph(XmlElement p) {
    final buffer = StringBuffer();
    for (final t in p.findAllElements('w:t')) {
      buffer.write(t.innerText);
    }
    return buffer.toString();
  }

  String _processParagraphs(List<XmlElement> paragraphs, Map<String, _Relationship> rels, Map<String, String> images, Map<String, String> footnotes, {bool isFootnoteContext = false}) {
     final buffer = StringBuffer();
     for (final p in paragraphs) {
       buffer.writeln(_processSingleParagraph(p, rels, images, footnotes, isFootnoteContext: isFootnoteContext));
     }
     return buffer.toString();
  }

  String _processSingleParagraph(XmlElement p, Map<String, _Relationship> rels, Map<String, String> images, Map<String, String> footnotes, {bool isFootnoteContext = false}) {
    // Determine block type (e.g., h1, h2, blockquote, p)
    String openTag = '<p>';
    String closeTag = '</p>';
    
    if (_isHeading(p)) {
      final pStyle = p.findAllElements('w:pStyle').firstOrNull;
      final val = pStyle?.getAttribute('w:val') ?? '';
      if (val.contains('1')) {
         openTag = '<h2>'; closeTag = '</h2>';
      } else if (val.contains('2')) {
         openTag = '<h3>'; closeTag = '</h3>';
      } else {
         openTag = '<h4>'; closeTag = '</h4>';
      }
    }

    final contentBuffer = StringBuffer();
    
    // Iterate over children of w:p to preserve order of runs, hyperlinks, and images
    for (final child in p.children) {
      if (child is XmlElement) {
        if (child.name.local == 'r') {
           contentBuffer.write(_processRun(child, images, footnotes, isFootnoteContext: isFootnoteContext));
        } else if (child.name.local == 'hyperlink') {
           final rId = child.getAttribute('r:id');
           final target = rId != null ? rels[rId]?.target : null;
           final linkContent = StringBuffer();
           for (final r in child.findAllElements('w:r')) {
              linkContent.write(_processRun(r, images, footnotes, isFootnoteContext: isFootnoteContext));
           }
           if (target != null && target.isNotEmpty) {
              contentBuffer.write('<a href="$target">$linkContent</a>');
           } else {
              contentBuffer.write(linkContent.toString());
           }
        }
      }
    }

    final content = contentBuffer.toString().trim();
    if (content.isEmpty) return '';

    // If footnote context, we don't wrap in p tag because we append inline
    if (isFootnoteContext) return content;

    return '$openTag$content$closeTag';
  }

  String _processRun(XmlElement r, Map<String, String> images, Map<String, String> footnotes, {bool isFootnoteContext = false}) {
    final buffer = StringBuffer();
    
    bool isBold = false;
    bool isItalic = false;
    bool isSuperscript = false;

    final rPr = r.findElements('w:rPr').firstOrNull;
    if (rPr != null) {
      if (rPr.findElements('w:b').isNotEmpty) isBold = true;
      if (rPr.findElements('w:i').isNotEmpty) isItalic = true;
      
      final vertAlign = rPr.findElements('w:vertAlign').firstOrNull;
      if (vertAlign?.getAttribute('w:val') == 'superscript') {
        isSuperscript = true;
      }
    }

    // Process Text
    for (final t in r.findElements('w:t')) {
       String text = _escapeHtml(t.innerText);
       buffer.write(text);
    }

    // Process Footnote Reference
    if (!isFootnoteContext) {
      final footnoteRef = r.findElements('w:footnoteReference').firstOrNull;
      if (footnoteRef != null) {
         final fnId = footnoteRef.getAttribute('w:id');
         if (fnId != null) {
            buffer.write('<sup><a href="#fn$fnId" id="ref$fnId">$fnId</a></sup>');
         }
      }
    }

    // Process Images
    final drawing = r.findElements('w:drawing').firstOrNull;
    if (drawing != null) {
       final blip = drawing.findAllElements('a:blip').firstOrNull;
       final embedId = blip?.getAttribute('r:embed');
       if (embedId != null && images.containsKey(embedId)) {
          final dataUri = images[embedId];
          buffer.write('<figure><img src="$dataUri" alt="Embedded Image" style="max-width: 100%;"></figure>');
       }
    }

    String result = buffer.toString();
    if (result.isEmpty) return '';

    if (isItalic) result = '<i>$result</i>';
    if (isBold) result = '<b>$result</b>';
    if (isSuperscript) result = '<sup>$result</sup>';

    return result;
  }

  String _escapeHtml(String text) {
    return text.replaceAll('&', '&amp;')
               .replaceAll('<', '&lt;')
               .replaceAll('>', '&gt;');
  }

  String _formatMonYYYY(DateTime date) {
    final months = [
      'Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'June',
      'July', 'Aug.', 'Sept.', 'Oct.', 'Nov.', 'Dec.',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _Relationship {
  final String target;
  final String type;
  _Relationship({required this.target, required this.type});
}
