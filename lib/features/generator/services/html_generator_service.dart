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
    String template = await rootBundle.loadString('assets/template.html');

    String baseUrl = settings.journalBaseUrl.trim();
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
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
      '{issueId}': metadata.issueId.trim(),
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
      
      '{abstract}': _clean(metadata.abstract_),
      '{keywords}': _clean(metadata.keywords),
      '{articleBody}': metadata.articleBodyHtml,
      '{authorBio}': _processAuthorBio(metadata),
      '{articleBibliography}': metadata.articleBibliography,
      '{articleFootnotes}': metadata.articleFootnotes,
    };

    String result = template;
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
}
