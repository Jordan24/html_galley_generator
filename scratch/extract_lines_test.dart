import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/generator/services/pdf_parser_service.dart';

void main() {
  test('print parsed pdf html body', () async {
    final file = File('/Users/jordan/Code/Projects/html_galleys/COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf');
    final parser = PdfParserService();
    final metadata = await parser.parse(file);
    print('PDF HTML BODY START:');
    print(metadata.articleBody.substring(0, 1500));
  });
}
