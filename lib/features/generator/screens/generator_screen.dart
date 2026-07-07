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
import '../services/pdf_parser_service.dart';
import '../services/docx_parser_service.dart';
import '../widgets/article_metadata_form.dart';
import '../widgets/author_metadata_form.dart';
import '../widgets/drop_zone.dart';
import '../widgets/output_preview_bar.dart';
import '../widgets/settings_form.dart';
import 'editor_screen.dart';

/// The main screen of the application. Orchestrates PDF parsing,
/// metadata editing, settings persistence, and HTML galley generation.
class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  // ... (dependencies and state remain the same) ...
  final _settingsRepo = SettingsRepository();
  final _pdfParser = PdfParserService();
  final _docxParser = DocxParserService();
  final _htmlGenerator = HtmlGeneratorService();
  final _ojsScraper = OjsScraperService();

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
  final _titleMainCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  final _articleBodyCtrl = TextEditingController();
  String _articleAbstract = '';

  // Settings controllers
  final _journalBaseUrlCtrl = TextEditingController();
  final _journalPathCtrl = TextEditingController();
  final _journalNameCtrl = TextEditingController();
  final _journalAbbrevCtrl = TextEditingController();
  final _journalIssnCtrl = TextEditingController();
  final _journalDoiIdCtrl = TextEditingController();
  final _journalOrganizationUrlCtrl = TextEditingController();
  final _supportingOrganizationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    final controllers = [
      _authorFullNameCtrl,
      _authorFirstNameCtrl,
      _authorLastNameCtrl,
      _authorOrcidCtrl,
      _authorAffiliationCtrl,
      _volumeCtrl,
      _issueCtrl,
      _articleIdCtrl,
      _submissionIdCtrl,
      _publicationIdCtrl,
      _issueViewIdCtrl,
      _pdfGalleyIdCtrl,
      _publishedDateCtrl,
      _issuedDateCtrl,
      _publishedDateMonYYYYCtrl,
      _publishYearCtrl,
      _submittedDateCtrl,
      _modifiedDateCtrl,
      _titleMainCtrl,
      _keywordsCtrl,
      _articleBodyCtrl,
      _journalBaseUrlCtrl,
      _journalPathCtrl,
      _journalNameCtrl,
      _journalAbbrevCtrl,
      _journalIssnCtrl,
      _journalDoiIdCtrl,
      _journalOrganizationUrlCtrl,
      _supportingOrganizationCtrl,
    ];
    for (final ctrl in controllers) {
      ctrl.addListener(_onFieldChanged);
    }
    _titleCtrl.addListener(_onTitleChanged);
    _authorBioQuill.addListener(_onFieldChanged);
    
    // Auto-fill listeners
    _articleIdCtrl.addListener(_onAutoFillTriggerChanged);
    _journalBaseUrlCtrl.addListener(_onAutoFillTriggerChanged);
    _journalPathCtrl.addListener(_onAutoFillTriggerChanged);
  }

  bool _isScraping = false;

  void _onAutoFillTriggerChanged() {
    if (_articleIdCtrl.text.isNotEmpty && 
        _journalBaseUrlCtrl.text.isNotEmpty && 
        _journalPathCtrl.text.isNotEmpty &&
        (_pdfGalleyIdCtrl.text.isEmpty || 
         _issueViewIdCtrl.text.isEmpty || 
         _authorAffiliationCtrl.text.isEmpty) &&
        !_isScraping) {
      _autoFillScrapedIds();
    }
    _onFieldChanged();
  }

  Future<void> _autoFillScrapedIds() async {
    if (_isScraping) return;
    
    final articleId = _articleIdCtrl.text;
    final baseUrl = _journalBaseUrlCtrl.text;
    final path = _journalPathCtrl.text;

    setState(() => _isScraping = true);

    final result = await _ojsScraper.scrapeArticlePage(
      baseUrl: baseUrl,
      journalPath: path,
      articleId: articleId,
    );

    if (mounted) {
      setState(() {
        _isScraping = false;
        bool isDefaultOrEmpty(String text, String defaultVal) {
          final trimmed = text.trim();
          return trimmed.isEmpty || trimmed == defaultVal;
        }

        if (result.pdfGalleyId != null && _pdfGalleyIdCtrl.text.isEmpty) {
          _pdfGalleyIdCtrl.text = result.pdfGalleyId!;
        }
        if (result.issueViewId != null && _issueViewIdCtrl.text.isEmpty) {
          _issueViewIdCtrl.text = result.issueViewId!;
        }
        if (result.authorAffiliation != null && _authorAffiliationCtrl.text.isEmpty) {
          _authorAffiliationCtrl.text = result.authorAffiliation!;
        }
        if (result.volume != null && isDefaultOrEmpty(_volumeCtrl.text, '7')) {
          _volumeCtrl.text = result.volume!;
        }
        if (result.issue != null && isDefaultOrEmpty(_issueCtrl.text, '1')) {
          _issueCtrl.text = result.issue!;
        }
        final todayStr = DateTime.now().toIso8601String().split('T').first;
        final todayYear = DateTime.now().year.toString();
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        final todayMonYYYY = '${months[DateTime.now().month - 1]} ${DateTime.now().year}';

        if (result.publishedDate != null && isDefaultOrEmpty(_publishedDateCtrl.text, todayStr)) {
          _publishedDateCtrl.text = result.publishedDate!;
        }
        if (result.issuedDate != null && isDefaultOrEmpty(_issuedDateCtrl.text, todayStr)) {
          _issuedDateCtrl.text = result.issuedDate!;
        }
        if (result.publishedDateMonYYYY != null && isDefaultOrEmpty(_publishedDateMonYYYYCtrl.text, todayMonYYYY)) {
          _publishedDateMonYYYYCtrl.text = result.publishedDateMonYYYY!;
        }
        if (result.publishYear != null && isDefaultOrEmpty(_publishYearCtrl.text, todayYear)) {
          _publishYearCtrl.text = result.publishYear!;
        }
        if (result.submittedDate != null && isDefaultOrEmpty(_submittedDateCtrl.text, todayStr)) {
          _submittedDateCtrl.text = result.submittedDate!;
        }
        if (result.modifiedDate != null && isDefaultOrEmpty(_modifiedDateCtrl.text, todayStr)) {
          _modifiedDateCtrl.text = result.modifiedDate!;
        }
      });
    }
  }

  void _onTitleChanged() {
    final text = _titleCtrl.text;
    if (text.contains(':')) {
      _titleMainCtrl.text = text.split(':').first.trim();
    } else {
      _titleMainCtrl.text = text;
    }
    _onFieldChanged();
  }

  void _onFieldChanged() {
    _rebuild();
    _settingsRepo.save(_currentSettings);
  }

  @override
  void dispose() {
    final controllers = [
      _titleCtrl,
      _authorFullNameCtrl,
      _authorFirstNameCtrl,
      _authorLastNameCtrl,
      _authorOrcidCtrl,
      _authorAffiliationCtrl,
      _volumeCtrl,
      _issueCtrl,
      _articleIdCtrl,
      _submissionIdCtrl,
      _publicationIdCtrl,
      _issueViewIdCtrl,
      _pdfGalleyIdCtrl,
      _publishedDateCtrl,
      _issuedDateCtrl,
      _publishedDateMonYYYYCtrl,
      _publishYearCtrl,
      _submittedDateCtrl,
      _modifiedDateCtrl,
      _titleMainCtrl,
      _keywordsCtrl,
      _articleBodyCtrl,
      _journalBaseUrlCtrl,
      _journalPathCtrl,
      _journalNameCtrl,
      _journalAbbrevCtrl,
      _journalIssnCtrl,
      _journalDoiIdCtrl,
      _journalOrganizationUrlCtrl,
      _supportingOrganizationCtrl,
    ];
    for (final ctrl in controllers) {
      ctrl.dispose();
    }
    _authorBioQuill.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  ArticleMetadata get _currentMetadata {
    final fullName = _authorFullNameCtrl.text;
    final lastName = fullName.isNotEmpty
        ? fullName.split(' ').last.toUpperCase()
        : '';

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
      issueViewId: _issueViewIdCtrl.text,
      pdfGalleyId: _pdfGalleyIdCtrl.text,
      publishedDate: _publishedDateCtrl.text,
      issuedDate: _issuedDateCtrl.text,
      publishedDateMonYYYY: _publishedDateMonYYYYCtrl.text,
      publishYear: _publishYearCtrl.text,
      submittedDate: _submittedDateCtrl.text,
      modifiedDate: _modifiedDateCtrl.text,
      keywords: _keywordsCtrl.text,
      articleBody: _articleBodyCtrl.text,
      titleMain: _titleMainCtrl.text,
      articleAbstract: _articleAbstract,
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
    publicationId: _publicationIdCtrl.text,
  );

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
      _publicationIdCtrl.text = settings.publicationId;
    });
  }

  Future<void> _processFile(File file) async {
    print('--- _processFile called with path: ${file.path} ---');
    setState(() => _selectedPdf = file);
    try {
      ArticleMetadata metadata;
      if (file.path.toLowerCase().endsWith('.pdf')) {
        metadata = await _pdfParser.parse(file);
      } else if (file.path.toLowerCase().endsWith('.docx')) {
        metadata = await _docxParser.parse(file);
      } else {
        throw Exception('Unsupported file format');
      }
      
      setState(() {
        _titleCtrl.text = metadata.title.replaceAll(
          RegExp(r'[^\x00-\x7F\u00C0-\u017F\u0180-\u024F]'),
          "'",
        );
        _authorFullNameCtrl.text = metadata.authorFullName;
        _authorFirstNameCtrl.text = metadata.authorFirstName;
        _authorLastNameCtrl.text = metadata.authorLastName;
        _authorOrcidCtrl.text = metadata.authorOrcid;
        _authorAffiliationCtrl.text = metadata.authorAffiliation;

        final bioDelta = HtmlToDelta(
          shouldInsertANewLine: (localName) => localName == 'p',
        ).convert(metadata.authorBio);
        _authorBioQuill.document = Document.fromDelta(bioDelta);

        _volumeCtrl.text = metadata.volume;
        _issueCtrl.text = metadata.issue;
        _issueViewIdCtrl.text = metadata.issueViewId;
        _pdfGalleyIdCtrl.text = metadata.pdfGalleyId;
        _articleIdCtrl.text = metadata.articleId;
        _submissionIdCtrl.text = metadata.submissionId;
        _publishedDateCtrl.text = metadata.publishedDate;
        _issuedDateCtrl.text = metadata.issuedDate;
        _publishedDateMonYYYYCtrl.text = metadata.publishedDateMonYYYY;
        _publishYearCtrl.text = metadata.publishYear;
        _submittedDateCtrl.text = metadata.submittedDate;
        _modifiedDateCtrl.text = metadata.modifiedDate;
        _titleMainCtrl.text = metadata.titleMain;
        _keywordsCtrl.text = metadata.keywords;
        _articleBodyCtrl.text = metadata.articleBody;
        _articleAbstract = metadata.articleAbstract;
      });
      _showSnackBar('Document parsed successfully!');
    } catch (e, stack) {
      debugPrint('Failed to parse document: $e\n$stack');
      _showSnackBar('Failed to parse document: $e');
    }
  }

  Future<void> _generateHtml() async {
    final metadata = _currentMetadata;
    final settings = _currentSettings;

    if (metadata.articleId.isEmpty) {
      _showSnackBar('Please provide an Article ID.');
      return;
    }

    await _settingsRepo.save(settings);

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            EditorScreen(metadata: metadata, settings: settings),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1400;
          final isMedium =
              constraints.maxWidth >= 900 && constraints.maxWidth < 1400;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropZone(selectedPdf: _selectedPdf, onFilePicked: _processFile),
                const SizedBox(height: 32),
                OutputPreviewBar(fileName: fileName, onGenerate: _generateHtml),
                const SizedBox(height: 32),
                _buildFormLayout(isWide, isMedium),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormLayout(bool isWide, bool isMedium) {
    final authorForm = AuthorMetadataForm(
      authorFullNameCtrl: _authorFullNameCtrl,
      authorFirstNameCtrl: _authorFirstNameCtrl,
      authorLastNameCtrl: _authorLastNameCtrl,
      authorOrcidCtrl: _authorOrcidCtrl,
      authorAffiliationCtrl: _authorAffiliationCtrl,
      authorBioQuill: _authorBioQuill,
    );

    final articleForm = ArticleMetadataForm(
      titleCtrl: _titleCtrl,
      volumeCtrl: _volumeCtrl,
      issueCtrl: _issueCtrl,
      articleIdCtrl: _articleIdCtrl,
      submissionIdCtrl: _submissionIdCtrl,
      issueViewIdCtrl: _issueViewIdCtrl,
      pdfGalleyIdCtrl: _pdfGalleyIdCtrl,
      publishedDateCtrl: _publishedDateCtrl,
      issuedDateCtrl: _issuedDateCtrl,
      publishedDateMonYYYYCtrl: _publishedDateMonYYYYCtrl,
      publishYearCtrl: _publishYearCtrl,
      submittedDateCtrl: _submittedDateCtrl,
      modifiedDateCtrl: _modifiedDateCtrl,
      titleMainCtrl: _titleMainCtrl,
      keywordsCtrl: _keywordsCtrl,
      articleBodyCtrl: _articleBodyCtrl,
    );

    final settingsForm = SettingsForm(
      journalBaseUrlCtrl: _journalBaseUrlCtrl,
      journalPathCtrl: _journalPathCtrl,
      journalNameCtrl: _journalNameCtrl,
      journalAbbrevCtrl: _journalAbbrevCtrl,
      journalIssnCtrl: _journalIssnCtrl,
      journalDoiIdCtrl: _journalDoiIdCtrl,
      journalOrganizationUrlCtrl: _journalOrganizationUrlCtrl,
      supportingOrganizationCtrl: _supportingOrganizationCtrl,
      publicationIdCtrl: _publicationIdCtrl,
    );

    if (isWide) {
      // 3 Columns: Author | Article | Journal
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: authorForm),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: articleForm),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: settingsForm),
        ],
      );
    } else if (isMedium) {
      // 2 Columns: Article | [Author + Journal]
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: articleForm),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              children: [authorForm, const SizedBox(height: 24), settingsForm],
            ),
          ),
        ],
      );
    } else {
      // 1 Column: Author -> Article -> Journal
      return Column(
        children: [
          authorForm,
          const SizedBox(height: 24),
          articleForm,
          const SizedBox(height: 24),
          settingsForm,
        ],
      );
    }
  }
}
