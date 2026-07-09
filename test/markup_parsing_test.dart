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
      
      // Verify italic translation and ensure it is not incorrectly bolded
      expect(metadata.articleBody, contains('<em>Special thanks to CU Boulder Library Instructor'));
      expect(metadata.articleBody, contains('Map Curator Naomi Heiser, Map Library Program Manager Ilene Raynes'));
      expect(metadata.articleBody, isNot(contains('<strong>Map Curator</strong>')));

      // Verify no raw asterisks in the body text (excluding template required field mark if any, but this is article body)
      expect(metadata.articleBody, isNot(contains('Map Curator**')));
      expect(metadata.articleBody, isNot(contains('Program Manager**')));

      // Verify paragraph breaks are preserved (the Introduction section is in its own paragraph, not merged)
      expect(metadata.articleBody, contains('<h2>Introduction</h2>'));
      expect(metadata.articleBody, contains('<p><em>Special thanks'));
      expect(metadata.articleBody, contains('<p>Following the profound impact of Edward Said’s'));

      // Verify figure captions are styled with font-size: 12px;
      expect(metadata.articleBody, contains('<p style="font-size: 12px;"><strong>Figure 1'));
      expect(metadata.articleBody, contains('<p style="font-size: 12px;"><strong>Figure 2'));
      expect(metadata.articleBody, contains('<p style="font-size: 12px;">Figure 3.'));

      // Verify footnote formatting and back-links in DOCX
      expect(metadata.articleBody, contains('<sup id="ref1"><a href="#fn1">[1]</a></sup>'));
      expect(metadata.articleBody, contains('<p id="fn1"><a href="#ref1">[1]</a> It is important to note that, as of summer 2025'));
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

    test('DOCX parser parses paragraph indentation from existing styled document', () async {
      final file = File('/Users/jordan/Code/Projects/html_galleys/html_galley_generator/assets/[STYLED] CHEUNG Kin_Transnational Asia_V8I1_A Chinese American Node of Healing.docx');
      expect(file.existsSync(), true);

      final parser = DocxParserService();
      final metadata = await parser.parse(file);

      // Verify paragraphs 55 and 61 are formatted as blockquotes with margin-left: 36.0pt; styling preserved
      expect(metadata.articleBody, contains('<blockquote style="margin-left: 36.0pt;">'));
      expect(metadata.articleBody, contains('My father’s innovative take on this practice'));
      expect(metadata.articleBody, contains('the lay Buddhist Huiguang invented'));
    });

    test('DOCX parser handles AI-generated image alt texts and newlines', () async {
      final file = File('/Users/jordan/Code/Projects/html_galleys/html_galley_generator/assets/[STYLED] PARK Sandra_Transnational Asia_V8I1_Conversion and Making the Anticommunist Body of Christ during the Korean War.docx');
      expect(file.existsSync(), true);

      final parser = DocxParserService();
      final metadata = await parser.parse(file);

      // Verify that image tags are correctly converted to HTML and disclaimers are removed
      expect(metadata.articleBody, contains('<img src="data:image/'));
      expect(metadata.articleBody, contains('alt="A close-up of a sign"'));
      expect(metadata.articleBody, contains('alt="A plaque with a cross and a star"'));
      expect(metadata.articleBody, isNot(contains('AI-generated content may be incorrect')));
      expect(metadata.articleBody, isNot(contains('Description automatically generated')));
    });
  });
}
