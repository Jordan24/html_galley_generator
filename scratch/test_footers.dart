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

      for (final zipFile in archive.files) {
        if (zipFile.name.startsWith('word/footer') || zipFile.name.startsWith('word/header')) {
          try {
            final xmlStr = utf8.decode(zipFile.content);
            final plainTextNoSpace = xmlStr.replaceAll(RegExp(r'<[^>]*>'), '');
            print('--- ${zipFile.name} (no space) ---');
            print(plainTextNoSpace);
          } catch (e) {
            print('Error in ${zipFile.name}: $e');
          }
        }
      }
    }
  }
}
