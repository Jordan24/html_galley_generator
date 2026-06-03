import 'dart:io';
import 'lib/features/generator/services/docx_parser_service.dart';

void main() async {
  final file = File('/Users/jordan/Code/Projects/html_galleys/Collins_Styled.docx');
  final parser = DocxParserService();
  final metadata = await parser.parse(file);
  print('Article ID: ${metadata.articleId}');
  print('Author: ${metadata.authorFullName}');
  print('Title: ${metadata.title}');
  await File('output_body.txt').writeAsString(metadata.articleBody);
}
