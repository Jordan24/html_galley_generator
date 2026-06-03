import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html_galley_generator/features/generator/services/docx_parser_service.dart';
import 'package:html_galley_generator/features/generator/services/pdf_parser_service.dart';

void main() {
  test('Verify DOCX parser does not include author byline in the article body', () async {
    final file = File('/Users/jordan/Code/Projects/html_galleys/Collins_Styled.docx');
    expect(file.existsSync(), true);

    final parser = DocxParserService();
    final metadata = await parser.parse(file);

    expect(metadata.title, 'Archives as Bridges: Connecting Students to Asia’s Histories');
    expect(metadata.authorFullName, 'Lauren Collins');
    expect(metadata.authorFirstName, 'Lauren');
    expect(metadata.authorLastName, 'Collins');
    expect(metadata.author, 'COLLINS');
    expect(metadata.authorAffiliation, contains('University of Colorado Boulder'));
    expect(metadata.authorBio, contains('Assistant Teaching Professor'));
    expect(metadata.articleAbstract, contains('This article explores the use of university libraries and archives'));
    expect(metadata.keywords, 'Teaching and Learning, Archives, Re-storying, Orphan Images, Libraries, Maps');
    // The body should NOT contain a standalone paragraph with the author's name
    expect(metadata.articleBody, isNot(contains('<p>Lauren Collins</p>')));
    expect(metadata.articleBody, isNot(contains('<p>Lauren Collins </p>')));
  });

  test('Verify PDF parser does not include author byline in the article body', () async {
    final file = File('/Users/jordan/Code/Projects/html_galleys/COLLINS+Lauren_Transnational+Asia_V7I1_Archives+as+Bridges_v2.pdf');
    expect(file.existsSync(), true);

    final parser = PdfParserService();
    final metadata = await parser.parse(file);

    expect(metadata.keywords, 'Teaching and Learning, Archives, Re-storying, Orphan Images, Libraries, Maps');
    // The body should NOT contain a standalone paragraph with the author's name
    expect(metadata.articleBody, isNot(contains('<p>Lauren Collins </p>')));
    expect(metadata.articleBody, isNot(contains('<p>Lauren Collins</p>')));
  });
}
