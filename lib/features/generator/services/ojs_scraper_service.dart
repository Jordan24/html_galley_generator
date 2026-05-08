import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class OjsScraperService {
  /// Fetches the article view page and extracts the PDF galley ID.
  /// The URL is constructed as: {baseUrl}/index.php/{journalPath}/article/view/{articleId}
  /// The pdfGalleyId is the last part of the URL the PDF button links to.
  Future<String?> scrapePdfGalleyId({
    required String baseUrl,
    required String journalPath,
    required String articleId,
  }) async {
    if (baseUrl.isEmpty || journalPath.isEmpty || articleId.isEmpty) {
      return null;
    }

    // Ensure baseUrl doesn't end with a slash for consistent construction
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final url = '$cleanBaseUrl/index.php/$journalPath/article/view/$articleId';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parse(response.body);
        
        // OJS 3 typically has links to galleys in a specific container or with specific classes.
        // We look for links that contain '/article/view/{articleId}/' and have 'pdf' in text or class.
        final links = document.querySelectorAll('a');
        for (final link in links) {
          final href = link.attributes['href'];
          if (href != null && href.contains('/article/view/$articleId/')) {
            final text = link.text.toLowerCase();
            final className = link.attributes['class']?.toLowerCase() ?? '';
            
            if (text.contains('pdf') || className.contains('pdf')) {
              // Extract the ID after the last slash
              // Example: .../article/view/113/191
              final uri = Uri.parse(href);
              final segments = uri.pathSegments;
              if (segments.isNotEmpty) {
                return segments.last;
              }
            }
          }
        }
      }
    } catch (e) {
      // Failed to scrape
    }
    return null;
  }
}
