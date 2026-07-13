import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'package:markdown/markdown.dart' as md;

/// Houses the heuristic rules and XML querying patterns to extract metadata properties
/// (titles, authors, volumes, issues, abstracts, and keywords) from a DOCX Zip Archive structure.
class DocxMetadataExtractor {
  /// Extracts Volume, Issue, and Article ID from headers/footers and DOI values in the ZIP archive.
  static Map<String, String> extractVolumeIssueArticleId(Archive archive) {
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

    return {
      'articleId': articleId,
      'volume': volume,
      'issue': issue,
    };
  }

  /// Extracts the fallback title and creator from the docProps/core.xml file.
  static Map<String, String> extractFallbackProps(Archive archive) {
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

    return {
      'fallbackTitle': fallbackTitle,
      'fallbackCreator': fallbackCreator,
    };
  }

  /// Finds and returns the paragraphs containing the Abstract.
  static List<String> extractAbstractParagraphs(List<String> paragraphs) {
    final abstractMarkdownParagraphs = <String>[];
    bool collectingAbstract = false;

    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
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
          final indentMatch = RegExp(r'\[:indent:[^\]]+\]').firstMatch(p);
          final indentMarker = indentMatch?.group(0) ?? '';
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

    return abstractMarkdownParagraphs;
  }

  /// Finds and returns the paragraphs containing the Keywords.
  static List<String> extractKeywordsParagraphs(List<String> paragraphs) {
    final keywordsMarkdownParagraphs = <String>[];
    bool collectingKeywords = false;

    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
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
          final indentMatch = RegExp(r'\[:indent:[^\]]+\]').firstMatch(p);
          final indentMarker = indentMatch?.group(0) ?? '';
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

    return keywordsMarkdownParagraphs;
  }

  /// Parses author name to extract first name, last name, and search bio matching.
  static Map<String, String> extractBioAndAffiliation({
    required String authorFullName,
    required List<String> paragraphs,
    required String Function(String) convertMarkdownToHtmlRobustly,
    required String Function(String) cleanHtmlToPlainText,
  }) {
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
          final robustP = convertMarkdownToHtmlRobustly(p);
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

    return {
      'authorBio': authorBio,
      'authorAffiliation': authorAffiliation,
    };
  }
}
