import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class OjsScrapeResult {
  final String? pdfGalleyId;
  final String? issueViewId;
  final String? authorAffiliation;

  OjsScrapeResult({this.pdfGalleyId, this.issueViewId, this.authorAffiliation});
}

class OjsScraperService {
  /// Fetches the article view page and extracts the PDF galley ID, Issue View ID, and Author Affiliation.
  /// The URL is constructed as: {baseUrl}/index.php/{journalPath}/article/view/{articleId}
  /// The pdfGalleyId is the last part of the URL the PDF button links to.
  /// The issueViewId is the last part of the URL the Issue link points to.
  Future<OjsScrapeResult> scrapeArticlePage({
    required String baseUrl,
    required String journalPath,
    required String articleId,
  }) async {
    if (baseUrl.isEmpty || journalPath.isEmpty || articleId.isEmpty) {
      return OjsScrapeResult();
    }

    // Ensure baseUrl doesn't end with a slash for consistent construction
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final url = '$cleanBaseUrl/index.php/$journalPath/article/view/$articleId';
    String? pdfGalleyId;
    String? issueViewId;
    String? authorAffiliation;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parse(response.body);

        // Extract author affiliation from meta tags first
        final metaTags = document.querySelectorAll('meta');
        for (final meta in metaTags) {
          final name = meta.attributes['name'];
          final content = meta.attributes['content'];
          if (name == 'citation_author_institution' && content != null && content.trim().isNotEmpty) {
            authorAffiliation = content.trim();
            break; // take first author's affiliation
          }
        }

        // Fallback to DOM elements if not found via meta tag
        if (authorAffiliation == null || authorAffiliation.isEmpty) {
          final selectors = [
            '.article-details-author-affiliation',
            '.author-affiliation',
            '.affiliation',
          ];
          for (final selector in selectors) {
            final element = document.querySelector(selector);
            if (element != null) {
              final text = element.text.trim();
              if (text.isNotEmpty) {
                authorAffiliation = text.replaceAll(RegExp(r'\s+'), ' ');
                break;
              }
            }
          }
        }
        
        // OJS 3 typically has links to galleys in a specific container or with specific classes.
        final links = document.querySelectorAll('a');
        for (final link in links) {
          final href = link.attributes['href'];
          if (href != null) {
            if (href.contains('/article/view/$articleId/')) {
              final text = link.text.toLowerCase();
              final className = link.attributes['class']?.toLowerCase() ?? '';
              
              if (text.contains('pdf') || className.contains('pdf')) {
                final uri = Uri.parse(href);
                final segments = uri.pathSegments;
                if (segments.isNotEmpty) {
                  pdfGalleyId = segments.last;
                }
              }
            } else if (href.contains('/issue/view/')) {
              final text = link.text.trim();
              // Check if the link text looks like "Vol. x No. y (Year)"
              if (text.toLowerCase().startsWith('vol.') || text.toLowerCase().contains('no.')) {
                final uri = Uri.parse(href);
                final segments = uri.pathSegments;
                if (segments.isNotEmpty) {
                  issueViewId = segments.last;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // Failed to scrape
    }
    return OjsScrapeResult(
      pdfGalleyId: pdfGalleyId,
      issueViewId: issueViewId,
      authorAffiliation: authorAffiliation,
    );
  }
}
