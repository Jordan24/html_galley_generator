import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../data/settings_repository.dart';
import '../models/article_metadata.dart';
import '../models/journal_settings.dart';
import '../services/html_generator_service.dart';
import '../services/ojs_scraper_service.dart';
import '../services/docx_parser_service.dart';

/// Manages metadata editing state, settings persistence, scraping operations,
/// and document ingestion independent of the UI layer.
class GeneratorController extends ChangeNotifier {
  final DocxParserService docxParser;
  final SettingsRepository settingsRepo = SettingsRepository();
  final OjsScraperService ojsScraper = OjsScraperService();
  final HtmlGeneratorService htmlGenerator = HtmlGeneratorService();

  File? _selectedFile;
  File? get selectedFile => _selectedFile;

  bool _isScraping = false;
  bool get isScraping => _isScraping;

  String _articleAbstract = '';
  String get articleAbstract => _articleAbstract;

  // Metadata Controllers
  final titleCtrl = TextEditingController();
  final authorFullNameCtrl = TextEditingController();
  final authorFirstNameCtrl = TextEditingController();
  final authorLastNameCtrl = TextEditingController();
  final authorOrcidCtrl = TextEditingController();
  final authorAffiliationCtrl = TextEditingController();
  final authorBioQuill = QuillController.basic();
  final volumeCtrl = TextEditingController();
  final issueCtrl = TextEditingController();
  final articleIdCtrl = TextEditingController();
  final submissionIdCtrl = TextEditingController();
  final publicationIdCtrl = TextEditingController();
  final issueViewIdCtrl = TextEditingController();
  final pdfGalleyIdCtrl = TextEditingController();
  final publishedDateCtrl = TextEditingController();
  final issuedDateCtrl = TextEditingController();
  final publishedDateMonYYYYCtrl = TextEditingController();
  final publishYearCtrl = TextEditingController();
  final submittedDateCtrl = TextEditingController();
  final modifiedDateCtrl = TextEditingController();
  final titleMainCtrl = TextEditingController();
  final keywordsCtrl = TextEditingController();
  final articleBodyCtrl = TextEditingController();

  // Settings Controllers
  final journalBaseUrlCtrl = TextEditingController();
  final journalPathCtrl = TextEditingController();
  final journalNameCtrl = TextEditingController();
  final journalAbbrevCtrl = TextEditingController();
  final journalIssnCtrl = TextEditingController();
  final journalDoiIdCtrl = TextEditingController();
  final journalOrganizationUrlCtrl = TextEditingController();
  final supportingOrganizationCtrl = TextEditingController();

  GeneratorController({
    DocxParserService? docxParser,
  })  : docxParser = docxParser ?? DocxParserService() {
    _init();
  }

  void _init() {
    // List of controllers that trigger settings persistence on change
    final settingsControllers = [
      journalBaseUrlCtrl,
      journalPathCtrl,
      journalNameCtrl,
      journalAbbrevCtrl,
      journalIssnCtrl,
      journalDoiIdCtrl,
      journalOrganizationUrlCtrl,
      supportingOrganizationCtrl,
    ];
    for (final ctrl in settingsControllers) {
      ctrl.addListener(_onSettingsFieldChanged);
    }

    // Title controller listener to compute titleMain automatically
    titleCtrl.addListener(_onTitleChanged);

    // Other controllers simply trigger UI rebuild notifications
    final otherControllers = [
      authorFullNameCtrl,
      authorFirstNameCtrl,
      authorLastNameCtrl,
      authorOrcidCtrl,
      authorAffiliationCtrl,
      volumeCtrl,
      issueCtrl,
      articleIdCtrl,
      submissionIdCtrl,
      publicationIdCtrl,
      issueViewIdCtrl,
      pdfGalleyIdCtrl,
      publishedDateCtrl,
      issuedDateCtrl,
      publishedDateMonYYYYCtrl,
      publishYearCtrl,
      submittedDateCtrl,
      modifiedDateCtrl,
      keywordsCtrl,
      articleBodyCtrl,
    ];
    for (final ctrl in otherControllers) {
      ctrl.addListener(notifyListeners);
    }
    authorBioQuill.addListener(notifyListeners);

    // Autofill trigger listeners
    articleIdCtrl.addListener(_onAutoFillTriggerChanged);
    journalBaseUrlCtrl.addListener(_onAutoFillTriggerChanged);
    journalPathCtrl.addListener(_onAutoFillTriggerChanged);
  }

  void _onSettingsFieldChanged() {
    settingsRepo.save(currentSettings);
    notifyListeners();
  }

  void _onTitleChanged() {
    final text = titleCtrl.text;
    if (text.contains(':')) {
      titleMainCtrl.text = text.split(':').first.trim();
    } else {
      titleMainCtrl.text = text;
    }
    notifyListeners();
  }

  void _onAutoFillTriggerChanged() {
    if (articleIdCtrl.text.isNotEmpty &&
        journalBaseUrlCtrl.text.isNotEmpty &&
        journalPathCtrl.text.isNotEmpty &&
        (pdfGalleyIdCtrl.text.isEmpty ||
         issueViewIdCtrl.text.isEmpty ||
         authorAffiliationCtrl.text.isEmpty ||
         publicationIdCtrl.text.isEmpty) &&
        !_isScraping) {
      autoFillScrapedIds();
    }
    notifyListeners();
  }

  /// Loads persisted settings values into their respective text fields.
  Future<void> loadSettings() async {
    final settings = await settingsRepo.load();
    journalBaseUrlCtrl.text = settings.journalBaseUrl;
    journalPathCtrl.text = settings.journalPath;
    journalNameCtrl.text = settings.journalName;
    journalAbbrevCtrl.text = settings.journalAbbrev;
    journalIssnCtrl.text = settings.journalIssn;
    journalDoiIdCtrl.text = settings.journalDoiId;
    journalOrganizationUrlCtrl.text = settings.journalOrganizationUrl;
    supportingOrganizationCtrl.text = settings.supportingOrganization;
    notifyListeners();
  }

  /// Scrapes publication info from the OJS server to auto-fill ID fields.
  Future<void> autoFillScrapedIds() async {
    if (_isScraping) return;

    final articleId = articleIdCtrl.text;
    final baseUrl = journalBaseUrlCtrl.text;
    final path = journalPathCtrl.text;

    _isScraping = true;
    notifyListeners();

    try {
      final result = await ojsScraper.scrapeArticlePage(
        baseUrl: baseUrl,
        journalPath: path,
        articleId: articleId,
      );

      bool isDefaultOrEmpty(String text, String defaultVal) {
        final trimmed = text.trim();
        return trimmed.isEmpty || trimmed == defaultVal;
      }

      if (result.pdfGalleyId != null && pdfGalleyIdCtrl.text.isEmpty) {
        pdfGalleyIdCtrl.text = result.pdfGalleyId!;
      }
      if (result.issueViewId != null && issueViewIdCtrl.text.isEmpty) {
        issueViewIdCtrl.text = result.issueViewId!;
      }
      if (result.authorAffiliation != null && result.authorAffiliation!.isNotEmpty) {
        authorAffiliationCtrl.text = result.authorAffiliation!;
      }
      if (result.authorOrcid != null && authorOrcidCtrl.text.isEmpty) {
        authorOrcidCtrl.text = result.authorOrcid!;
      }
      if (result.publicationId != null) {
        publicationIdCtrl.text = result.publicationId!;
      }
      if (result.volume != null && isDefaultOrEmpty(volumeCtrl.text, '7')) {
        volumeCtrl.text = result.volume!;
      }
      if (result.issue != null && isDefaultOrEmpty(issueCtrl.text, '1')) {
        issueCtrl.text = result.issue!;
      }
      
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final todayYear = DateTime.now().year.toString();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final todayMonYYYY = '${months[DateTime.now().month - 1]} ${DateTime.now().year}';

      if (result.publishedDate != null && isDefaultOrEmpty(publishedDateCtrl.text, todayStr)) {
        publishedDateCtrl.text = result.publishedDate!;
      }
      if (result.issuedDate != null && isDefaultOrEmpty(issuedDateCtrl.text, todayStr)) {
        issuedDateCtrl.text = result.issuedDate!;
      }
      if (result.publishedDateMonYYYY != null && isDefaultOrEmpty(publishedDateMonYYYYCtrl.text, todayMonYYYY)) {
        publishedDateMonYYYYCtrl.text = result.publishedDateMonYYYY!;
      }
      if (result.publishYear != null && isDefaultOrEmpty(publishYearCtrl.text, todayYear)) {
        publishYearCtrl.text = result.publishYear!;
      }
      if (result.submittedDate != null && isDefaultOrEmpty(submittedDateCtrl.text, todayStr)) {
        submittedDateCtrl.text = result.submittedDate!;
      }
      if (result.modifiedDate != null && isDefaultOrEmpty(modifiedDateCtrl.text, todayStr)) {
        modifiedDateCtrl.text = result.modifiedDate!;
      }
    } catch (_) {
      // Ignore scraper failures to keep heuristics non-disruptive
    } finally {
      _isScraping = false;
      notifyListeners();
    }
  }

  /// Processes dropping a new DOCX file by clearing previous state and parsing.
  Future<void> processFile(File file, {required void Function(String) onStatus}) async {
    _selectedFile = file;
    
    // Clear editing fields
    titleCtrl.clear();
    authorFullNameCtrl.clear();
    authorFirstNameCtrl.clear();
    authorLastNameCtrl.clear();
    authorOrcidCtrl.clear();
    authorAffiliationCtrl.clear();
    authorBioQuill.document = Document();
    volumeCtrl.clear();
    issueCtrl.clear();
    issueViewIdCtrl.clear();
    pdfGalleyIdCtrl.clear();
    articleIdCtrl.clear();
    submissionIdCtrl.clear();
    publicationIdCtrl.clear();
    publishedDateCtrl.clear();
    issuedDateCtrl.clear();
    publishedDateMonYYYYCtrl.clear();
    publishYearCtrl.clear();
    submittedDateCtrl.clear();
    modifiedDateCtrl.clear();
    titleMainCtrl.clear();
    keywordsCtrl.clear();
    articleBodyCtrl.clear();
    _articleAbstract = '';
    
    notifyListeners();

    try {
      ArticleMetadata metadata;
      if (file.path.toLowerCase().endsWith('.docx')) {
        metadata = await docxParser.parse(file);
      } else {
        throw Exception('Unsupported file format. Please upload a DOCX file.');
      }

      titleCtrl.text = metadata.title.replaceAll(
        RegExp(r'[^\x00-\x7F\u00C0-\u017F\u0180-\u024F]'),
        "'",
      );
      authorFullNameCtrl.text = metadata.authorFullName;
      authorFirstNameCtrl.text = metadata.authorFirstName;
      authorLastNameCtrl.text = metadata.authorLastName;
      authorOrcidCtrl.text = metadata.authorOrcid;
      authorAffiliationCtrl.text = metadata.authorAffiliation;

      if (metadata.authorBio.isNotEmpty) {
        final bioDelta = HtmlToDelta(
          shouldInsertANewLine: (localName) => localName == 'p' || localName == 'blockquote',
        ).convert(metadata.authorBio);
        authorBioQuill.document = Document.fromDelta(bioDelta);
      } else {
        authorBioQuill.document = Document();
      }

      volumeCtrl.text = metadata.volume;
      issueCtrl.text = metadata.issue;
      issueViewIdCtrl.text = metadata.issueViewId;
      pdfGalleyIdCtrl.text = metadata.pdfGalleyId;
      articleIdCtrl.text = metadata.articleId;
      submissionIdCtrl.text = metadata.submissionId;
      publicationIdCtrl.text = metadata.publicationId;
      publishedDateCtrl.text = metadata.publishedDate;
      issuedDateCtrl.text = metadata.issuedDate;
      publishedDateMonYYYYCtrl.text = metadata.publishedDateMonYYYY;
      publishYearCtrl.text = metadata.publishYear;
      submittedDateCtrl.text = metadata.submittedDate;
      modifiedDateCtrl.text = metadata.modifiedDate;
      titleMainCtrl.text = metadata.titleMain;
      keywordsCtrl.text = metadata.keywords;
      articleBodyCtrl.text = metadata.articleBody;
      _articleAbstract = metadata.articleAbstract;
      
      notifyListeners();
      onStatus('Document parsed successfully!');
    } catch (e, stack) {
      debugPrint('Failed to parse document: $e\n$stack');
      _selectedFile = null;
      notifyListeners();
      onStatus('Failed to parse document: $e');
    }
  }

  /// Compiles editing data into an ArticleMetadata model object.
  ArticleMetadata get currentMetadata {
    final fullName = authorFullNameCtrl.text;
    final lastName = fullName.isNotEmpty
        ? fullName.split(' ').last.toUpperCase()
        : '';

    final delta = authorBioQuill.document.toDelta();
    final converter = QuillDeltaToHtmlConverter(delta.toJson());
    final bioHtml = converter.convert();

    return ArticleMetadata(
      title: titleCtrl.text,
      author: lastName,
      authorFullName: fullName,
      authorFirstName: authorFirstNameCtrl.text,
      authorLastName: authorLastNameCtrl.text,
      authorOrcid: authorOrcidCtrl.text,
      authorAffiliation: authorAffiliationCtrl.text,
      authorBio: bioHtml,
      volume: volumeCtrl.text,
      issue: issueCtrl.text,
      articleId: articleIdCtrl.text,
      submissionId: submissionIdCtrl.text,
      publicationId: publicationIdCtrl.text,
      issueViewId: issueViewIdCtrl.text,
      pdfGalleyId: pdfGalleyIdCtrl.text,
      publishedDate: publishedDateCtrl.text,
      issuedDate: issuedDateCtrl.text,
      publishedDateMonYYYY: publishedDateMonYYYYCtrl.text,
      publishYear: publishYearCtrl.text,
      submittedDate: submittedDateCtrl.text,
      modifiedDate: modifiedDateCtrl.text,
      keywords: keywordsCtrl.text,
      articleBody: articleBodyCtrl.text,
      titleMain: titleMainCtrl.text,
      articleAbstract: _articleAbstract,
    );
  }

  /// Compiles OJS server details into a JournalSettings model object.
  JournalSettings get currentSettings => JournalSettings(
    journalBaseUrl: journalBaseUrlCtrl.text,
    journalPath: journalPathCtrl.text,
    journalName: journalNameCtrl.text,
    journalAbbrev: journalAbbrevCtrl.text,
    journalIssn: journalIssnCtrl.text,
    journalDoiId: journalDoiIdCtrl.text,
    journalOrganizationUrl: journalOrganizationUrlCtrl.text,
    supportingOrganization: supportingOrganizationCtrl.text,
  );

  @override
  void dispose() {
    final allControllers = [
      titleCtrl,
      authorFullNameCtrl,
      authorFirstNameCtrl,
      authorLastNameCtrl,
      authorOrcidCtrl,
      authorAffiliationCtrl,
      volumeCtrl,
      issueCtrl,
      articleIdCtrl,
      submissionIdCtrl,
      publicationIdCtrl,
      issueViewIdCtrl,
      pdfGalleyIdCtrl,
      publishedDateCtrl,
      issuedDateCtrl,
      publishedDateMonYYYYCtrl,
      publishYearCtrl,
      submittedDateCtrl,
      modifiedDateCtrl,
      titleMainCtrl,
      keywordsCtrl,
      articleBodyCtrl,
      journalBaseUrlCtrl,
      journalPathCtrl,
      journalNameCtrl,
      journalAbbrevCtrl,
      journalIssnCtrl,
      journalDoiIdCtrl,
      journalOrganizationUrlCtrl,
      supportingOrganizationCtrl,
    ];
    for (final ctrl in allControllers) {
      ctrl.dispose();
    }
    authorBioQuill.dispose();
    super.dispose();
  }
}
