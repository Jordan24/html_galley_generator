import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:html_galley_generator/features/generator/services/orcid_service.dart';

void main() {
  group('OrcidService Tests', () {
    test(
      'Search for Lauren Collins from University of Colorado should return correct ORCID',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.host, 'pub.orcid.org');
          expect(request.url.queryParameters['q'], contains('Lauren Collins'));
          expect(request.url.queryParameters['q'], contains('University of Colorado'));
          
          return http.Response(
            json.encode({
              'result': [
                {
                  'orcid-identifier': {'path': '0000-0002-2168-3352'}
                }
              ]
            }),
            200,
          );
        });

        final orcidService = OrcidService(client: mockClient);
        final result = await orcidService.findOrcid(
          'Lauren Collins',
          affiliation: 'the University of Colorado Boulder',
        );

        expect(result, isNotNull);
        expect(result, '0000-0002-2168-3352');
      },
    );

    test('Search with non-existent author should return null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({'result': <dynamic>[]}), 200);
      });

      final orcidService = OrcidService(client: mockClient);
      final result = await orcidService.findOrcid(
        'AveryNonExistentAuthorName12345',
      );
      expect(result, isNull);
    });

    test('Search with empty name should return null', () async {
      final orcidService = OrcidService();
      final result = await orcidService.findOrcid('');
      expect(result, isNull);
    });
  });
}
