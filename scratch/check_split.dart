import 'dart:io';
import 'package:archive/archive.dart';
import 'package:docx_to_markdown/docx_to_markdown.dart';

void main() async {
  final bytes = await File('/Users/jordan/Code/Projects/html_galleys/Collins_Styled.docx').readAsBytes();
  final converter = DocxConverter(bytes);
  String markdown = await converter.convert();
  
  // Preprocess markdown like docx_parser_service does
  String cleanMarkdown = markdown.replaceAll(RegExp(r'''<a\s+id=["'][\w\d]+["']>\s*</a>'''), '');
  
  // Footnote extraction
  final fnDefRegex = RegExp(r'^\[\^([^\]]+)\]:\s*(.*)$', multiLine: true);
  final matches = fnDefRegex.allMatches(cleanMarkdown).toList();
  for (final match in matches.reversed) {
    cleanMarkdown = cleanMarkdown.substring(0, match.start) + cleanMarkdown.substring(match.end);
  }
  
  final paragraphs = cleanMarkdown.split(RegExp(r'\n\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  
  for (int i = 0; i < paragraphs.length; i++) {
    final p = paragraphs[i];
    if (p.contains('Special thanks') || p.contains('Following the profound')) {
      print('Paragraph $i:');
      print('---');
      print(p);
      print('---');
    }
  }
}
