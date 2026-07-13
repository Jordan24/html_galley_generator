import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:html_galley_generator/features/generator/services/ojs_scraper_service.dart';

void main() {
  group('OjsScraperService Tests', () {
    test(
      'Scrape article page for Justin B. Stein (Rice TA 123) should extract affiliation, pdfGalleyId, and issueViewId',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'https://transnationalasia.rice.edu/index.php/ta/article/view/123');
          
          final html = '''
<html>
  <head>
    <meta name="citation_author_institution" content="Kwantlen Polytechnic University" />
    <meta name="citation_date" content="2026-07-06" />
    <meta name="DC.Date.created" content="2026-07-06" />
    <meta name="DC.Date.issued" content="2026-07-06" />
    <meta name="DC.Date.dateSubmitted" content="2025-09-26" />
    <meta name="DC.Date.modified" content="2026-07-07" />
    <meta name="citation_volume" content="8" />
    <meta name="citation_issue" content="1" />
  </head>
  <body>
    <!-- publicationId=117 -->
    <a href="https://transnationalasia.rice.edu/index.php/ta/article/view/123/200" class="pdf">PDF</a>
    <a href="https://transnationalasia.rice.edu/index.php/ta/issue/view/16">Vol. 8 No. 1 (2026)</a>
  </body>
</html>
''';
          return http.Response(html, 200);
        });

        final scraper = OjsScraperService(client: mockClient);
        final result = await scraper.scrapeArticlePage(
          baseUrl: 'https://transnationalasia.rice.edu',
          journalPath: 'ta',
          articleId: '123',
        );

        expect(result.authorAffiliation, equals('Kwantlen Polytechnic University'));
        expect(result.pdfGalleyId, equals('200'));
        expect(result.issueViewId, equals('16'));
        expect(result.publishedDate, equals('2026-07-06'));
        expect(result.issuedDate, equals('2026-07-06'));
        expect(result.publishedDateMonYYYY, equals('Jul 2026'));
        expect(result.publishYear, equals('2026'));
        expect(result.submittedDate, equals('2025-09-26'));
        expect(result.modifiedDate, equals('2026-07-07'));
        expect(result.volume, equals('8'));
        expect(result.issue, equals('1'));
        expect(result.publicationId, equals('117'));
      },
    );

    test(
      'Scrape article page for Natasha Mikles (Rice TA 135) should extract ORCID',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'https://transnationalasia.rice.edu/index.php/ta/article/view/135');
          
          final html = '''
<html>
  <head>
    <meta name="citation_author_institution" content="Texas State University" />
  </head>
  <body>
    <!-- publicationId=129 -->
    <a href="https://transnationalasia.rice.edu/index.php/ta/article/view/135/202" class="pdf">PDF</a>
    <a href="https://transnationalasia.rice.edu/index.php/ta/issue/view/16">Vol. 8 No. 1 (2026)</a>
    <a href="https://orcid.org/0000-0001-6236-537X">ORCID</a>
  </body>
</html>
''';
          return http.Response(html, 200);
        });

        final scraper = OjsScraperService(client: mockClient);
        final result = await scraper.scrapeArticlePage(
          baseUrl: 'https://transnationalasia.rice.edu',
          journalPath: 'ta',
          articleId: '135',
        );

        expect(result.authorAffiliation, equals('Texas State University'));
        expect(result.pdfGalleyId, equals('202'));
        expect(result.issueViewId, equals('16'));
        expect(result.authorOrcid, equals('0000-0001-6236-537X'));
        expect(result.publicationId, equals('129'));
      },
    );

    test('Scrape with non-existent article should return null/empty values', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html><body>Not Found</body></html>', 404);
      });

      final scraper = OjsScraperService(client: mockClient);
      final result = await scraper.scrapeArticlePage(
        baseUrl: 'https://transnationalasia.rice.edu',
        journalPath: 'ta',
        articleId: '9999999',
      );
      expect(result.authorAffiliation, isNull);
      expect(result.pdfGalleyId, isNull);
      expect(result.issueViewId, isNull);
    });

    test('Scrape with empty inputs should return empty scrape result', () async {
      final scraper = OjsScraperService();
      final result = await scraper.scrapeArticlePage(
        baseUrl: '',
        journalPath: '',
        articleId: '',
      );
      expect(result.authorAffiliation, isNull);
      expect(result.pdfGalleyId, isNull);
      expect(result.issueViewId, isNull);
    });
  });
}
