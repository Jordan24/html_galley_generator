import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html_galley_generator/features/generator/services/docx_parser_service.dart';
import 'test_utils.dart';

void main() {
  test('Verify DOCX parser does not include author byline in the article body', () async {
    final file = createMockDocxFile(
      title: 'Transnational Politics and Korean Evangelicalism: Affective Infrastructure and History',
      author: 'Minjung Noh',
      affiliation: 'Lehigh University',
      bio: 'Minjung Noh is a scholar at Lehigh University.',
      abstractText: 'This article examines the political resonance of contemporary Korean evangelicalism...',
      keywords: 'Korean Evangelicalism',
      bodyText: 'By an ethos of existential revenge',
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    final parser = DocxParserService();
    final metadata = await parser.parse(XFile(file.path));

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
