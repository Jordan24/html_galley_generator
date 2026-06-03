import 'dart:io';
import '../lib/features/generator/services/pdf_parser_service.dart';

void main() async {
  final file = File('/Users/jordan/Code/Projects/html_galleys/COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf');
  final parser = PdfParserService();
  final metadata = await parser.parse(file);
  
  if (metadata.articleBody.contains('Special thanks')) {
    final idx = metadata.articleBody.indexOf('Special thanks');
    print(metadata.articleBody.substring(idx - 100, idx + 800));
  } else {
    print('Not found');
  }
}
