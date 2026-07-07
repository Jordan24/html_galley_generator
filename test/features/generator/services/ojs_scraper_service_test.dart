import 'package:flutter_test/flutter_test.dart';
import 'package:html_galley_generator/features/generator/services/ojs_scraper_service.dart';

void main() {
  group('OjsScraperService Tests', () {
    final scraper = OjsScraperService();

    test(
      'Scrape article page for Justin B. Stein (Rice TA 123) should extract affiliation, pdfGalleyId, and issueViewId',
      () async {
        // This test performs a real network request.
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
        expect(result.modifiedDate, equals('2026-07-06'));
      },
    );

    test('Scrape with non-existent article should return null/empty values', () async {
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
