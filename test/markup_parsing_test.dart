import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html_galley_generator/features/generator/services/docx_parser_service.dart';
import 'package:html_galley_generator/features/generator/services/pdf_parser_service.dart';

void main() {
  group('Markup Parsing and Translation Tests', () {
    test('DOCX parser parses malformed markdown and preserves paragraphs', () async {
      final file = File('/Users/jordan/Code/Projects/html_galleys/Collins_Styled.docx');
      expect(file.existsSync(), true);

      final parser = DocxParserService();
      final metadata = await parser.parse(file);

      // Verify plain text metadata fields
      expect(metadata.articleAbstract, isNot(contains('<p>')));
      expect(metadata.articleAbstract, isNot(contains('**')));
      expect(metadata.articleAbstract, isNot(contains('*')));
      expect(metadata.articleAbstract, contains('This article explores the use of university libraries'));

      expect(metadata.keywords, 'Teaching and Learning, Archives, Re-storying, Orphan Images, Libraries, Maps');

      // Verify HTML article body structure
      expect(metadata.articleBody, contains('<h2>Abstract</h2>'));
      expect(metadata.articleBody, contains('<h2>Keywords</h2>'));
      
      // Verify robust bold translation (including overlapping/mismatched markers)
      expect(metadata.articleBody, contains('<strong>Map Curator</strong>'));
      expect(metadata.articleBody, contains('<strong>, Map Library Program Manager</strong>'));
      
      // Verify italic translation
      expect(metadata.articleBody, contains('<em>Special thanks to CU Boulder Library Instructor'));

      // Verify no raw asterisks in the body text (excluding template required field mark if any, but this is article body)
      expect(metadata.articleBody, isNot(contains('Map Curator**')));
      expect(metadata.articleBody, isNot(contains('Program Manager**')));

      // Verify paragraph breaks are preserved (the Introduction section is in its own paragraph, not merged)
      expect(metadata.articleBody, contains('<h2>Introduction</h2>'));
      expect(metadata.articleBody, contains('<p><em>Special thanks'));
      expect(metadata.articleBody, contains('<p>Following the profound impact of Edward Said’s'));
    });

    test('PDF parser extracts abstract and keywords with rich styling', () async {
      final file = File('/Users/jordan/Code/Projects/html_galleys/COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf');
      expect(file.existsSync(), true);

      final parser = PdfParserService();
      final metadata = await parser.parse(file);

      // Verify plain text metadata fields
      expect(metadata.articleAbstract, isNot(contains('<p>')));
      expect(metadata.articleAbstract, contains('This article explores the use of university libraries'));

      // Verify HTML body abstract/keywords has formatting and section styling
      expect(metadata.articleBody, contains('<h2>Abstract</h2>'));
      expect(metadata.articleBody, contains('<h2>Keywords</h2>'));
      expect(metadata.articleBody, contains('<i>Special thanks to'));
      expect(metadata.articleBody, contains('Map Curator'));
      expect(metadata.articleBody, contains('Library Program Manager'));
      expect(metadata.articleBody, contains('<i>Orientalism</i>'));
      expect(metadata.articleBody, contains('<h2><b>Introduction</b></h2>'));
      expect(metadata.articleBody, contains('<h2><i>A. Map Library: Cartographic Constructions of Asia</i></h2>'));
    });
  });
}
