import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';

void main() async {
  final dir = Directory('/Users/jordan/Code/Projects/html_galleys');
  for (final entity in dir.listSync()) {
    if (entity is File && entity.path.endsWith('.docx')) {
      print('=============================================');
      print('FILE: ${entity.path}');
      print('=============================================');
      final bytes = await entity.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      String articleId = '';
      String volume = '7';
      String issue = '1';

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

      print('Extracted Volume: $volume');
      print('Extracted Issue: $issue');
      print('Extracted Article ID: $articleId');
    }
  }
}
