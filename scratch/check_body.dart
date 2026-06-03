import 'dart:io';
import '../lib/features/generator/services/docx_parser_service.dart';

void main() async {
  final file = File('/Users/jordan/Code/Projects/html_galleys/Collins_Styled.docx');
  final parser = DocxParserService();
  final metadata = await parser.parse(file);
  
  // Print first 1000 characters of the body to see paragraphs
  print(metadata.articleBody.substring(0, 2000));
}
