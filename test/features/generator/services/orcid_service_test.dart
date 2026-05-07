import 'package:flutter_test/flutter_test.dart';
import 'package:html_galley_generator/features/generator/services/orcid_service.dart';

void main() {
  group('OrcidService Tests', () {
    final orcidService = OrcidService();

    test(
      'Search for Lauren Collins from University of Colorado should return correct ORCID',
      () async {
        // This test performs a real network request to the ORCID Public API.
        final result = await orcidService.findOrcid(
          'Lauren Collins',
          affiliation: 'the University of Colorado Boulder',
        );

        expect(result, isNotNull);
        expect(result, '0000-0002-2168-3352');
      },
    );

    test('Search with non-existent author should return null', () async {
      final result = await orcidService.findOrcid(
        'AveryNonExistentAuthorName12345',
      );
      expect(result, isNull);
    });

    test('Search with empty name should return null', () async {
      final result = await orcidService.findOrcid('');
      expect(result, isNull);
    });
  });
}
