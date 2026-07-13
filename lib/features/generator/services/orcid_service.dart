import 'dart:convert';
import 'package:http/http.dart' as http;

class OrcidService {
  final http.Client _client;

  OrcidService({http.Client? client}) : _client = client ?? http.Client();

  /// Searches for an ORCID ID by author name and optional affiliation.
  /// Returns the first ORCID ID found, or null.
  Future<String?> findOrcid(String fullName, {String? affiliation}) async {
    final name = fullName.trim();
    var aff = affiliation?.trim();

    if (name.isEmpty) return null;

    // Clean affiliation: remove leading "the", "of", etc.
    if (aff != null) {
      aff = aff.replaceFirst(
        RegExp(r'^(the|of|a|an)\s+', caseSensitive: false),
        '',
      );
    }

    // Build query: use broader syntax for better matching
    String query = 'text:($name)';
    if (aff != null && aff.isNotEmpty && aff.length < 150) {
      // Remove any characters that might break the Lucene query syntax
      final safeAff = aff.replaceAll(RegExp(r'[\(\)\[\]\{\}\^\~\?\:\\]'), ' ');
      query += ' AND affiliation-org-name:($safeAff)';
    }

    try {
      final uri = Uri.https('pub.orcid.org', '/v3.0/search', {'q': query});
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['result'] as List?;

        if (results != null && results.isNotEmpty) {
          // Return the first match's ORCID
          final firstMatch = results.first as Map;
          final orcidIdentifier = firstMatch['orcid-identifier'] as Map?;
          if (orcidIdentifier != null) {
            return orcidIdentifier['path'] as String?;
          }
        }
      }
    } catch (e) {
      // Error searching ORCID
    }

    // Fallback 1: search by name only if affiliation search was used and returned nothing
    if (aff != null && aff.isNotEmpty) {
      return findOrcid(name); // Recursive call without affiliation
    }

    // Fallback 2: If name search with parentheses failed, try a very broad search
    if (!query.contains('affiliation-org-name') && query.contains('(')) {
      try {
        final broadUri = Uri.https('pub.orcid.org', '/v3.0/search', {
          'q': name,
        });
        final response = await _client.get(
          broadUri,
          headers: {'Accept': 'application/json'},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['result'] as List?;
          if (results != null && results.isNotEmpty) {
            final firstMatch = results.first as Map;
            final orcidIdentifier = firstMatch['orcid-identifier'] as Map?;
            return orcidIdentifier?['path'] as String?;
          }
        }
      } catch (_) {}
    }

    return null;
  }
}
