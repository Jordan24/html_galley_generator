import 'package:flutter/services.dart';
import '../models/article_metadata.dart';
import '../models/journal_settings.dart';

class HtmlGeneratorService {
  String buildFileName(ArticleMetadata metadata) {
    final vol = metadata.volume.trim();
    final iss = metadata.issue.trim();
    final auth = metadata.author.trim().replaceAll(' ', '+');

    String title = metadata.title.split(':').first.trim();
    title = _clean(title)
        .replaceAll("'", '')
        .replaceAll('"', '')
        .replaceAll(' ', '+');

    return 'Vol+$vol+No+${iss}_${auth}_$title.html';
  }

  Future<String> buildHtml(ArticleMetadata metadata, JournalSettings settings) async {
    final articleMain = await buildArticleMain(metadata, settings);
    return buildFullHtml(articleMain, metadata, settings);
  }

  Future<String> buildArticleMain(ArticleMetadata metadata, JournalSettings settings) async {
    String template = await rootBundle.loadString('assets/template.html');
    // Target only the inner content div within the abstract block
    final contentMatch = RegExp(
      r'(<div class="article-details-block article-details-abstract">\s*<div>)(.*?)(</div>)',
      dotAll: true,
    ).firstMatch(template);

    if (contentMatch == null) return '';
    
    String content = contentMatch.group(2)!;
    return _applyReplacements(content, metadata, settings);
  }

  Future<String> buildFullHtml(String articleContent, ArticleMetadata metadata, JournalSettings settings) async {
    String template = await rootBundle.loadString('assets/template.html');
    
    // Post-process articleContent to restore/ensure proper footnote back-links and ids
    // 1. Convert any inline footnote citation to the target format: <sup id="ref$id"><a href="#fn$id">[$id]</a></sup>
    var processedContent = articleContent.replaceAllMapped(
      RegExp(r'(?:<sup[^>]*?>\s*)?<a\s+[^>]*?href="#fn(\d+)"[^>]*?>\s*(?:<[^>]+>)*\s*\[?(\d+)\]?\s*(?:</[^>]+>)*\s*</a>(?:\s*</sup>)?'),
      (match) {
        final id = match.group(1)!;
        return '<sup id="ref$id"><a href="#fn$id">[$id]</a></sup>';
      }
    );

    // 2. Convert any footnote paragraph starting link to the target format: <p id="fn$id"><a href="#ref$id">[$id]</a>
    processedContent = processedContent.replaceAllMapped(
      RegExp(r'<p([^>]*?)>(\s*(?:<[^>]+>)*\s*<a\s+[^>]*?href="#ref(\d+)"[^>]*?>\s*(?:<[^>]+>)*\s*\[?(\d+)\]?\s*(?:</[^>]+>)*\s*</a>)'),
      (match) {
        final pAttrs = match.group(1)!;
        final id = match.group(3)!;
        if (pAttrs.contains('id="fn')) {
          return match.group(0)!;
        }
        final space = pAttrs.isEmpty ? '' : ' ';
        return '<p$space$pAttrs id="fn$id"><a href="#ref$id">[$id]</a>';
      }
    );

    // 3. Ensure all internal links starting with "#" stay in the same page by setting target="_self"
    processedContent = processedContent.replaceAllMapped(
      RegExp(r'<a\s+([^>]*?)href="#([^"]+)"([^>]*?)>'),
      (match) {
        var before = match.group(1)!;
        var href = match.group(2)!;
        var after = match.group(3)!;
        before = before.replaceAll('target="_blank"', '').replaceAll('target="_parent"', '').replaceAll('target="_self"', '').replaceAll(RegExp(r'\s+'), ' ').trim();
        after = after.replaceAll('target="_blank"', '').replaceAll('target="_parent"', '').replaceAll('target="_self"', '').replaceAll(RegExp(r'\s+'), ' ').trim();
        final spaceBefore = before.isNotEmpty ? ' $before' : '';
        final spaceAfter = after.isNotEmpty ? ' $after' : '';
        return '<a$spaceBefore href="#$href"$spaceAfter target="_self">';
      }
    );

    // Replace only the inner content of the article body block with a placeholder
    final resultTemplate = template.replaceFirstMapped(
      RegExp(r'(<div class="article-details-block article-details-abstract">\s*<div>)(.*?)(</div>)', dotAll: true),
      (match) => '${match.group(1)}{articleContent}${match.group(3)}'
    );

    String result = _applyReplacements(resultTemplate, metadata, settings);
    return result.replaceFirst('{articleContent}', processedContent);
  }

  String _applyReplacements(String text, ArticleMetadata metadata, JournalSettings settings) {
    String baseUrl = settings.journalBaseUrl.trim();
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    String result = text;
    if (metadata.authorOrcid.trim().isEmpty) {
      result = result.replaceAll(
        RegExp(r'<link\s+[^>]*?orcidProfile\.css[^>]*?>\s*', caseSensitive: false, dotAll: true),
        '',
      );
      result = result.replaceAll(
        RegExp(r'<a\s+class="orcidImage"[^>]*?>.*?</a>\s*', caseSensitive: false, dotAll: true),
        '',
      );
      result = result.replaceAll(
        RegExp(r'<div\s+class="article-details-author-orcid"[^>]*?>.*?</div>\s*', caseSensitive: false, dotAll: true),
        '',
      );
    }

    final replacements = {
      '{journalBaseUrl}': baseUrl,
      '{journalPath}': settings.journalPath.trim(),
      '{journalName}': _clean(settings.journalName),
      '{journalAbbrev}': _clean(settings.journalAbbrev),
      '{journalIssn}': settings.journalIssn.trim(),
      '{journalDoiId}': settings.journalDoiId.trim(),
      '{journalOrganizationUrl}': settings.journalOrganizationUrl.trim(),
      '{supportingOrganization}': _clean(settings.supportingOrganization),
      
      '{articleId}': metadata.articleId.trim(),
      '{publicationId}': metadata.publicationId.trim(),
      '{issueViewId}': metadata.issueViewId.trim(),
      '{pdfGalleyId}': metadata.pdfGalleyId.trim(),
      
      '{articleTitle}': _clean(metadata.title),
      '{titleMain}': _clean(metadata.titleMain),
      '{authorFullName}': _clean(metadata.authorFullName),
      '{authorFirstName}': _clean(metadata.authorFirstName),
      '{authorLastName}': _clean(metadata.authorLastName),
      '{authorOrcid}': metadata.authorOrcid.trim(),
      '{authorAffiliation}': _clean(metadata.authorAffiliation),
      
      '{journalVolume}': metadata.volume.trim(),
      '{journalIssue}': metadata.issue.trim(),
      
      '{publishedDate}': metadata.publishedDate.trim(),
      '{publishDate}': metadata.publishedDate.trim(),
      '{issuedDate}': metadata.issuedDate.trim(),
      '{submittedDate}': metadata.submittedDate.trim(),
      '{modifiedDate}': metadata.modifiedDate.trim(),
      '{publishDateMonYYYY}': metadata.publishedDateMonYYYY.trim(),
      '{publishYear}': metadata.publishYear.trim(),
      '{year}': metadata.publishYear.trim(),
      
      '{keywords}': _clean(metadata.keywords),
      '{articleAbstract}': _clean(metadata.articleAbstract),
      '{dcSubjectTags}': _generateKeywordTags(metadata.keywords, 'DC.Subject'),
      '{citationKeywordsTags}': _generateKeywordTags(metadata.keywords, 'citation_keywords'),
      '{articleBody}': _cleanRedundantTags(metadata.articleBody),
      '{authorBio}': _cleanRedundantTags(_processAuthorBio(metadata)),
    };

    replacements.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }

  String _processAuthorBio(ArticleMetadata metadata) {
    if (metadata.authorBio.isEmpty) return '';
    
    final fullName = _clean(metadata.authorFullName);
    final bio = metadata.authorBio;
    final boldName = '<strong>$fullName</strong>';
    
    // Ensure author name is bolded at the start if it exists
    if (bio.startsWith('<p>')) {
      if (bio.startsWith('<p>$boldName')) return bio;
      if (bio.startsWith('<p>$fullName')) {
        return bio.replaceFirst('<p>$fullName', '<p>$boldName');
      }
    } else {
      if (bio.startsWith(boldName)) return '<p>$bio</p>';
      if (bio.startsWith(fullName)) {
        return '<p>$boldName${bio.substring(fullName.length)}</p>';
      }
      return '<p>$bio</p>';
    }
    return bio;
  }

  String _generateKeywordTags(String keywords, String tagName) {
    if (keywords.isEmpty) return '';
    final list = keywords.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    return list.map((k) => '<meta name="$tagName" xml:lang="en" content="${_clean(k)}"/>').join('\n\t');
  }

  String _clean(String text) {
    if (text.isEmpty) return '';
    return text.trim()
        .replaceAll('\uFFFD', "'")
        .replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u2032\u2035\u02BC\u02BD\u02C8\u02CA\u02CB\u00B4\u0060\u0090\u0091\u0092]'), "'")
        .replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F\u2033\u2036\u0093\u0094\u00AB\u00BB]'), '"')
        .replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'), '-')
        .replaceAll('\uFB01', 'fi')
        .replaceAll('\uFB02', 'fl')
        .replaceAll(RegExp(r'[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\uFEFF]'), ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _cleanRedundantTags(String html) {
    if (html.isEmpty) return html;
    
    String result = html;
    
    // Tags to collapse if they are adjacent and identical
    final tags = ['i', 'em', 'b', 'strong', 'sup', 'sub', 'span'];
    
    for (final tag in tags) {
      // Matches </tag> followed by optional whitespace/newlines then <tag>
      final regex = RegExp('</$tag>(\\s*)<$tag>', caseSensitive: false, dotAll: true);
      
      // Keep replacing until no more merges are possible (handles triplets etc)
      int previousLength;
      do {
        previousLength = result.length;
        result = result.replaceAllMapped(regex, (match) => match.group(1) ?? '');
      } while (result.length != previousLength);
    }
    
    return result;
  }
}
