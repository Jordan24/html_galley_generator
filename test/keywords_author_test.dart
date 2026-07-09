import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html_galley_generator/features/generator/services/docx_parser_service.dart';
import 'package:html_galley_generator/features/generator/services/pdf_parser_service.dart';

void main() {
  test('Verify DOCX parser does not include author byline in the article body', () async {
    final file = File('/Users/jordan/Code/Projects/html_galleys/html_galley_generator/assets/[STYLED] NOH Minjung_Transnational Asia_V8I1_Transnational Politics and Korean Evangelicalism.docx');
    expect(file.existsSync(), true);

    final parser = DocxParserService();
    final metadata = await parser.parse(file);

    expect(metadata.title, 'Transnational Politics and Korean Evangelicalism: Affective Infrastructure and History');
    expect(metadata.authorFullName, 'Minjung Noh');
    expect(metadata.authorFirstName, 'Minjung');
    expect(metadata.authorLastName, 'Noh');
    expect(metadata.author, 'NOH');
    expect(metadata.authorBio, contains('Lehigh University'));
    expect(metadata.articleAbstract, contains('This article examines the political resonance of contemporary Korean evangelicalism'));
    expect(metadata.keywords, contains('Korean Evangelicalism'));
    
    // The body should NOT contain a standalone paragraph with the author's name
    expect(metadata.articleBody, isNot(contains('<p>Minjung Noh</p>')));
    expect(metadata.articleBody, isNot(contains('<p>Minjung Noh </p>')));
  });
}
