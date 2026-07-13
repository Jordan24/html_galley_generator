import 'package:flutter_test/flutter_test.dart';
import 'package:html_galley_generator/features/generator/services/docx_parser_service.dart';
import 'test_utils.dart';

void main() {
  group('Markup Parsing and Translation Tests', () {
    test('DOCX parser parses metadata and preserves paragraphs from Minjung Noh document', () async {
      final file = createMockDocxFile(
        title: 'Transnational Politics and Korean Evangelicalism: Affective Infrastructure and History',
        author: 'Minjung Noh',
        affiliation: 'Lehigh University',
        abstractText: 'This article examines the political resonance of contemporary Korean evangelicalism...',
        keywords: 'Korean Evangelicalism, religion',
        bodyText: 'By an ethos of existential revenge',
      );
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      final parser = DocxParserService();
      final metadata = await parser.parse(file);

      // Verify plain text metadata fields
      expect(metadata.title, 'Transnational Politics and Korean Evangelicalism: Affective Infrastructure and History');
      expect(metadata.authorFullName, 'Minjung Noh');
      expect(metadata.authorFirstName, 'Minjung');
      expect(metadata.authorLastName, 'Noh');
      expect(metadata.author, 'NOH');
      expect(metadata.keywords, contains('Korean Evangelicalism'));
      expect(metadata.articleAbstract, contains('This article examines the political resonance of contemporary Korean evangelicalism'));

      // Verify HTML article body structure
      expect(metadata.articleBody, contains('<h2>Abstract</h2>'));
      expect(metadata.articleBody, contains('<h2>Keywords</h2>'));
      expect(metadata.articleBody, contains('<h2>Notes</h2>'));

      // Verify blockquote / paragraph indentation is preserved
      expect(metadata.articleBody, contains('<blockquote style="margin-left: 36.0pt;">'));
      expect(metadata.articleBody, contains('By an ethos of existential revenge'));

      // Verify footnote formatting and back-links in DOCX
      expect(metadata.articleBody, contains('<sup id="ref1"><a href="#fn1">[1]</a></sup>'));
      expect(metadata.articleBody, contains('<p id="fn1"><a href="#ref1">[1]</a>'));
    });

    test('DOCX parser handles NOH Minjung images throughout pipeline', () async {
      final file = createMockDocxFile(
        title: 'Transnational Politics and Korean Evangelicalism: Affective Infrastructure and History',
        author: 'Minjung Noh',
        affiliation: 'Lehigh University',
        abstractText: 'This article examines the political resonance of contemporary Korean evangelicalism...',
        keywords: 'Korean Evangelicalism, religion',
        bodyText: 'In February 2020. The Christian element of the channel is less prominent.',
        images: [
          {
            'name': 'image1.png',
            'alt': 'A picture containing text, outdoor\nDescription automatically generated',
          },
          {
            'name': 'image2.png',
            'alt': 'A screenshot of a video game',
          },
          {
            'name': 'image3.png',
            'alt': 'A group of people standing in front of a computer',
          }
        ],
      );
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      final parser = DocxParserService();
      final metadata = await parser.parse(file);

      // Verify that the body was successfully parsed and is not empty
      expect(metadata.articleBody.isNotEmpty, true);
      expect(metadata.articleBody, contains('In February 2020'));
      expect(metadata.articleBody, contains('The Christian element of the channel is less prominent'));

      // Verify that the images are correctly resolved to base64
      expect(metadata.articleBody, contains('<img src="data:image/png;base64,'));
      
      // Verify that raw alt text newlines and description disclaimers are removed
      expect(metadata.articleBody, contains('alt="A picture containing text, outdoor"'));
      expect(metadata.articleBody, contains('alt="A screenshot of a video game"'));
      expect(metadata.articleBody, contains('alt="A group of people standing in front of a computer"'));
      expect(metadata.articleBody, isNot(contains('Description automatically generated')));
    });
  });
}
