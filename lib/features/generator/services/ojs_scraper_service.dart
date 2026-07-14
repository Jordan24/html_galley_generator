import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:flutter/foundation.dart' show kIsWeb;

class OjsScrapeResult {
  final String? pdfGalleyId;
  final String? issueViewId;
  final String? authorAffiliation;
  final String? publishedDate;
  final String? issuedDate;
  final String? publishedDateMonYYYY;
  final String? publishYear;
  final String? submittedDate;
  final String? modifiedDate;
  final String? volume;
  final String? issue;
  final String? publicationId;
  final String? authorOrcid;

  OjsScrapeResult({
    this.pdfGalleyId,
    this.issueViewId,
    this.authorAffiliation,
    this.publishedDate,
    this.issuedDate,
    this.publishedDateMonYYYY,
    this.publishYear,
    this.submittedDate,
    this.modifiedDate,
    this.volume,
    this.issue,
    this.publicationId,
    this.authorOrcid,
  });
}

class OjsScraperService {
  final http.Client _client;

  OjsScraperService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches the article view page and extracts the PDF galley ID, Issue View ID, Author Affiliation, and dates.
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
    String? publishedDate;
    String? issuedDate;
    String? publishedDateMonYYYY;
    String? publishYear;
    String? submittedDate;
    String? modifiedDate;
    String? volume;
    String? issue;
    String? publicationId;
    String? authorOrcid;

    try {
      http.Response response;
      try {
        response = await _client.get(Uri.parse(url));
      } catch (e) {
        if (kIsWeb) {
          final proxiedUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
          response = await _client.get(Uri.parse(proxiedUrl));
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200) {
        final document = parse(response.body);

        final pubIdMatch = RegExp(r'publicationId=(\d+)').firstMatch(response.body);
        if (pubIdMatch != null) {
          publicationId = pubIdMatch.group(1);
        }

        String? metaCitationDate;
        String? metaDcDateCreated;
        String? metaDcDateIssued;
        String? metaDcDateSubmitted;
        String? metaDcDateModified;

        // Extract author affiliation and dates from meta tags first
        final metaTags = document.querySelectorAll('meta');
        for (final meta in metaTags) {
          final name = meta.attributes['name'];
          final content = meta.attributes['content']?.trim();
          if (content == null || content.isEmpty) continue;

          if (name == 'citation_author_institution' && authorAffiliation == null) {
            authorAffiliation = content;
          } else if (name == 'citation_date') {
            metaCitationDate = content;
          } else if (name == 'DC.Date.created') {
            metaDcDateCreated = content;
          } else if (name == 'DC.Date.issued') {
            metaDcDateIssued = content;
          } else if (name == 'DC.Date.dateSubmitted') {
            metaDcDateSubmitted = content;
          } else if (name == 'DC.Date.modified') {
            metaDcDateModified = content;
          } else if (name == 'DC.Source.Volume' || name == 'citation_volume') {
            volume = content;
          } else if (name == 'DC.Source.Issue' || name == 'citation_issue') {
            issue = content;
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

        // Fallback DOM parse for published date
        String? domPublishedDate;
        final publishedElement = document.querySelector('.article-details-published');
        if (publishedElement != null) {
          final text = publishedElement.text.replaceAll('Published', '').trim();
          final dateRegex = RegExp(r'\b\d{4}[-/]\d{2}[-/]\d{2}\b');
          final match = dateRegex.firstMatch(text);
          if (match != null) {
            domPublishedDate = match.group(0)?.replaceAll('/', '-');
          } else if (text.isNotEmpty) {
            domPublishedDate = text.replaceAll('/', '-');
          }
        }

        final rawPublishedDate = metaCitationDate ?? metaDcDateIssued ?? metaDcDateCreated ?? domPublishedDate;
        if (rawPublishedDate != null) {
          publishedDate = rawPublishedDate.replaceAll('/', '-').trim();
        }

        issuedDate = metaDcDateIssued?.replaceAll('/', '-').trim() ?? publishedDate;
        submittedDate = metaDcDateSubmitted?.replaceAll('/', '-').trim() ?? publishedDate;
        modifiedDate = metaDcDateModified?.replaceAll('/', '-').trim() ?? publishedDate;

        if (publishedDate != null) {
          final yearMatch = RegExp(r'\b\d{4}\b').firstMatch(publishedDate);
          if (yearMatch != null) {
            publishYear = yearMatch.group(0);
          }

          try {
            final parsedDate = DateTime.parse(publishedDate);
            final months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
            ];
            publishedDateMonYYYY = '${months[parsedDate.month - 1]} ${parsedDate.year}';
          } catch (_) {
            final parts = publishedDate.split('-');
            if (parts.length >= 2) {
              final year = parts[0];
              final monthInt = int.tryParse(parts[1]);
              if (monthInt != null && monthInt >= 1 && monthInt <= 12) {
                final months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                ];
                publishedDateMonYYYY = '${months[monthInt - 1]} $year';
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
            } else if (href.contains('orcid.org')) {
              final uri = Uri.parse(href);
              final segments = uri.pathSegments;
              if (segments.isNotEmpty) {
                final lastSegment = segments.last.trim();
                if (RegExp(r'^\d{4}-\d{4}-\d{4}-[\dX]{4}$').hasMatch(lastSegment)) {
                  authorOrcid = lastSegment;
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
      publishedDate: publishedDate,
      issuedDate: issuedDate,
      publishedDateMonYYYY: publishedDateMonYYYY,
      publishYear: publishYear,
      submittedDate: submittedDate,
      modifiedDate: modifiedDate,
      volume: volume,
      issue: issue,
      publicationId: publicationId,
      authorOrcid: authorOrcid,
    );
  }
}
