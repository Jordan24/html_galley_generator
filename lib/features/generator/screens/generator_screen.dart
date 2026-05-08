import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../data/settings_repository.dart';
import '../models/article_metadata.dart';
import '../models/journal_settings.dart';
import '../services/html_generator_service.dart';
import '../services/pdf_parser_service.dart';
import '../widgets/drop_zone.dart';
import '../widgets/metadata_form.dart';
import '../widgets/output_preview_bar.dart';
import '../widgets/settings_form.dart';

/// The main screen of the application. Orchestrates PDF parsing,
/// metadata editing, settings persistence, and HTML galley generation.
class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  // ── Dependencies ────────────────────────────────────────────────────────────
  final _settingsRepo = SettingsRepository();
  final _pdfParser = PdfParserService();
  final _htmlGenerator = HtmlGeneratorService();

  // ── State ───────────────────────────────────────────────────────────────────
  File? _selectedPdf;

  // Metadata controllers
  final _titleCtrl = TextEditingController();
  final _authorFullNameCtrl = TextEditingController();
  final _authorFirstNameCtrl = TextEditingController();
  final _authorLastNameCtrl = TextEditingController();
  final _authorOrcidCtrl = TextEditingController();
  final _authorAffiliationCtrl = TextEditingController();
  final _authorBioQuill = QuillController.basic();
  final _volumeCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _articleIdCtrl = TextEditingController();
  final _submissionIdCtrl = TextEditingController();
  final _publicationIdCtrl = TextEditingController();
  final _issueViewIdCtrl = TextEditingController();
  final _pdfGalleyIdCtrl = TextEditingController();
  final _publishedDateCtrl = TextEditingController();
  final _issuedDateCtrl = TextEditingController();
  final _publishedDateMonYYYYCtrl = TextEditingController();
  final _publishYearCtrl = TextEditingController();
  final _submittedDateCtrl = TextEditingController();
  final _modifiedDateCtrl = TextEditingController();
  final _articleBibliographyCtrl = TextEditingController();
  final _articleFootnotesCtrl = TextEditingController();
  final _titleMainCtrl = TextEditingController();
  final _issueIdCtrl = TextEditingController();
  final _abstractCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  final _articleBodyHtmlCtrl = TextEditingController();

  // Settings controllers
  final _journalBaseUrlCtrl = TextEditingController();
  final _journalPathCtrl = TextEditingController();
  final _journalNameCtrl = TextEditingController();
  final _journalAbbrevCtrl = TextEditingController();
  final _journalIssnCtrl = TextEditingController();
  final _journalDoiIdCtrl = TextEditingController();
  final _journalOrganizationUrlCtrl = TextEditingController();
  final _supportingOrganizationCtrl = TextEditingController();

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSettings();
    final controllers = [
      _titleCtrl, _authorFullNameCtrl, _authorFirstNameCtrl, _authorLastNameCtrl,
      _authorOrcidCtrl, _authorAffiliationCtrl,
      _volumeCtrl, _issueCtrl,
      _articleIdCtrl, _submissionIdCtrl, _publicationIdCtrl, _issueViewIdCtrl,
      _pdfGalleyIdCtrl, _publishedDateCtrl, _issuedDateCtrl,
      _publishedDateMonYYYYCtrl, _publishYearCtrl,
      _submittedDateCtrl, _modifiedDateCtrl,
      _articleBibliographyCtrl, _articleFootnotesCtrl,
      _titleMainCtrl, _issueIdCtrl,
      _abstractCtrl, _keywordsCtrl, _articleBodyHtmlCtrl,
    ];
    for (final ctrl in controllers) {
      ctrl.addListener(_rebuild);
    }
    _authorBioQuill.addListener(_rebuild);
  }

  @override
  void dispose() {
    final controllers = [
      _titleCtrl, _authorFullNameCtrl, _authorFirstNameCtrl, _authorLastNameCtrl,
      _authorOrcidCtrl, _authorAffiliationCtrl,
      _volumeCtrl, _issueCtrl,
      _articleIdCtrl, _submissionIdCtrl, _publicationIdCtrl, _issueViewIdCtrl,
      _pdfGalleyIdCtrl, _publishedDateCtrl, _issuedDateCtrl,
      _publishedDateMonYYYYCtrl, _publishYearCtrl,
      _submittedDateCtrl, _modifiedDateCtrl,
      _articleBibliographyCtrl, _articleFootnotesCtrl,
      _titleMainCtrl, _issueIdCtrl,
      _abstractCtrl, _keywordsCtrl, _articleBodyHtmlCtrl,
      _journalBaseUrlCtrl, _journalPathCtrl, _journalNameCtrl, _journalAbbrevCtrl,
      _journalIssnCtrl, _journalDoiIdCtrl, _journalOrganizationUrlCtrl, _supportingOrganizationCtrl,
    ];
    for (final ctrl in controllers) {
      ctrl.dispose();
    }
    _authorBioQuill.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _rebuild() => setState(() {});

  ArticleMetadata get _currentMetadata {
    final fullName = _authorFullNameCtrl.text;
    final lastName = fullName.isNotEmpty ? fullName.split(' ').last.toUpperCase() : '';
    
    // Convert Quill Delta to HTML for metadata
    final delta = _authorBioQuill.document.toDelta();
    final converter = QuillDeltaToHtmlConverter(delta.toJson());
    final bioHtml = converter.convert();

    return ArticleMetadata(
      title: _titleCtrl.text,
      author: lastName,
      authorFullName: fullName,
      authorFirstName: _authorFirstNameCtrl.text,
      authorLastName: _authorLastNameCtrl.text,
      authorOrcid: _authorOrcidCtrl.text,
      authorAffiliation: _authorAffiliationCtrl.text,
      authorBio: bioHtml,
      volume: _volumeCtrl.text,
      issue: _issueCtrl.text,
      articleId: _articleIdCtrl.text,
      submissionId: _submissionIdCtrl.text,
      publicationId: _publicationIdCtrl.text,
      issueViewId: _issueViewIdCtrl.text,
      pdfGalleyId: _pdfGalleyIdCtrl.text,
      publishedDate: _publishedDateCtrl.text,
      issuedDate: _issuedDateCtrl.text,
      publishedDateMonYYYY: _publishedDateMonYYYYCtrl.text,
      publishYear: _publishYearCtrl.text,
      submittedDate: _submittedDateCtrl.text,
      modifiedDate: _modifiedDateCtrl.text,
      abstract_: _abstractCtrl.text,
      keywords: _keywordsCtrl.text,
      articleBodyHtml: _articleBodyHtmlCtrl.text,
      articleBibliography: _articleBibliographyCtrl.text,
      articleFootnotes: _articleFootnotesCtrl.text,
      titleMain: _titleMainCtrl.text,
      issueId: _issueIdCtrl.text,
    );
  }

  JournalSettings get _currentSettings => JournalSettings(
    journalBaseUrl: _journalBaseUrlCtrl.text,
    journalPath: _journalPathCtrl.text,
    journalName: _journalNameCtrl.text,
    journalAbbrev: _journalAbbrevCtrl.text,
    journalIssn: _journalIssnCtrl.text,
    journalDoiId: _journalDoiIdCtrl.text,
    journalOrganizationUrl: _journalOrganizationUrlCtrl.text,
    supportingOrganization: _supportingOrganizationCtrl.text,
  );

  // ── Settings persistence ──────────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.load();
    setState(() {
      _journalBaseUrlCtrl.text = settings.journalBaseUrl;
      _journalPathCtrl.text = settings.journalPath;
      _journalNameCtrl.text = settings.journalName;
      _journalAbbrevCtrl.text = settings.journalAbbrev;
      _journalIssnCtrl.text = settings.journalIssn;
      _journalDoiIdCtrl.text = settings.journalDoiId;
      _journalOrganizationUrlCtrl.text = settings.journalOrganizationUrl;
      _supportingOrganizationCtrl.text = settings.supportingOrganization;
    });
  }

  // ── PDF processing ────────────────────────────────────────────────────────────
  Future<void> _processFile(File file) async {
    setState(() => _selectedPdf = file);
    try {
      final metadata = await _pdfParser.parse(file);
      setState(() {
        _titleCtrl.text = metadata.title.replaceAll(RegExp(r'[^\x00-\x7F\u00C0-\u017F\u0180-\u024F]'), "'");
        _authorFullNameCtrl.text = metadata.authorFullName;
        _authorFirstNameCtrl.text = metadata.authorFirstName;
        _authorLastNameCtrl.text = metadata.authorLastName;
        _authorOrcidCtrl.text = metadata.authorOrcid;
        _authorAffiliationCtrl.text = metadata.authorAffiliation;
        
        // Reset and populate Quill editor
        _authorBioQuill.document = Document()..insert(0, metadata.authorBio);
        
        _volumeCtrl.text = metadata.volume;
        _issueCtrl.text = metadata.issue;
        _articleIdCtrl.text = metadata.articleId;
        _submissionIdCtrl.text = metadata.submissionId;
        _publicationIdCtrl.text = metadata.publicationId;
        _issueViewIdCtrl.text = metadata.issueViewId;
        _pdfGalleyIdCtrl.text = metadata.pdfGalleyId;
        _publishedDateCtrl.text = metadata.publishedDate;
        _issuedDateCtrl.text = metadata.issuedDate;
        _publishedDateMonYYYYCtrl.text = metadata.publishedDateMonYYYY;
        _publishYearCtrl.text = metadata.publishYear;
        _submittedDateCtrl.text = metadata.submittedDate;
        _modifiedDateCtrl.text = metadata.modifiedDate;
        _articleBibliographyCtrl.text = metadata.articleBibliography;
        _articleFootnotesCtrl.text = metadata.articleFootnotes;
        _titleMainCtrl.text = metadata.titleMain;
        _issueIdCtrl.text = metadata.issueId;
        _abstractCtrl.text = metadata.abstract_;
        _keywordsCtrl.text = metadata.keywords;
        _articleBodyHtmlCtrl.text = metadata.articleBodyHtml;
      });
      _showSnackBar('PDF parsed successfully!');
    } catch (e) {
      _showSnackBar('Failed to parse PDF: $e');
    }
  }

  // ── HTML generation ───────────────────────────────────────────────────────────
  Future<void> _generateHtml() async {
    final metadata = _currentMetadata;
    final settings = _currentSettings;

    if (metadata.articleId.isEmpty) {
      _showSnackBar('Please provide an Article ID.');
      return;
    }

    await _settingsRepo.save(settings);

    final suggestedName = _htmlGenerator.buildFileName(metadata);
    final saveLocation = await getSaveLocation(suggestedName: suggestedName);
    if (saveLocation == null) return;

    final htmlContent = await _htmlGenerator.buildHtml(metadata, settings);
    await File(saveLocation.path).writeAsString(htmlContent);
    _showSnackBar('HTML Galley generated successfully!');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final metadata = _currentMetadata;
    final fileName = _htmlGenerator.buildFileName(metadata);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text(
          'OJS HTML Galley Generator',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropZone(
              selectedPdf: _selectedPdf,
              onFilePicked: _processFile,
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: MetadataForm(
                    titleCtrl: _titleCtrl,
                    authorFullNameCtrl: _authorFullNameCtrl,
                    authorFirstNameCtrl: _authorFirstNameCtrl,
                    authorLastNameCtrl: _authorLastNameCtrl,
                    authorOrcidCtrl: _authorOrcidCtrl,
                    authorAffiliationCtrl: _authorAffiliationCtrl,
                    authorBioQuill: _authorBioQuill,
                    volumeCtrl: _volumeCtrl,
                    issueCtrl: _issueCtrl,
                    articleIdCtrl: _articleIdCtrl,
                    submissionIdCtrl: _submissionIdCtrl,
                    publicationIdCtrl: _publicationIdCtrl,
                    issueViewIdCtrl: _issueViewIdCtrl,
                    pdfGalleyIdCtrl: _pdfGalleyIdCtrl,
                    publishedDateCtrl: _publishedDateCtrl,
                    issuedDateCtrl: _issuedDateCtrl,
                    publishedDateMonYYYYCtrl: _publishedDateMonYYYYCtrl,
                    publishYearCtrl: _publishYearCtrl,
                    submittedDateCtrl: _submittedDateCtrl,
                    modifiedDateCtrl: _modifiedDateCtrl,
                    articleBibliographyCtrl: _articleBibliographyCtrl,
                    articleFootnotesCtrl: _articleFootnotesCtrl,
                    titleMainCtrl: _titleMainCtrl,
                    issueIdCtrl: _issueIdCtrl,
                    abstractCtrl: _abstractCtrl,
                    keywordsCtrl: _keywordsCtrl,
                    articleBodyHtmlCtrl: _articleBodyHtmlCtrl,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: SettingsForm(
                    journalBaseUrlCtrl: _journalBaseUrlCtrl,
                    journalPathCtrl: _journalPathCtrl,
                    journalNameCtrl: _journalNameCtrl,
                    journalAbbrevCtrl: _journalAbbrevCtrl,
                    journalIssnCtrl: _journalIssnCtrl,
                    journalDoiIdCtrl: _journalDoiIdCtrl,
                    journalOrganizationUrlCtrl: _journalOrganizationUrlCtrl,
                    supportingOrganizationCtrl: _supportingOrganizationCtrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            OutputPreviewBar(
              fileName: fileName,
              onGenerate: _generateHtml,
            ),
          ],
        ),
      ),
    );
  }
}
