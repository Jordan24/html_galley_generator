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
  ArticleMetadata? _parsedMetadata;

  // Metadata controllers
  final _titleCtrl = TextEditingController();
  final _authorFullNameCtrl = TextEditingController();
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
  final _submittedDateCtrl = TextEditingController();
  final _modifiedDateCtrl = TextEditingController();

  // Settings controllers
  final _baseUrlCtrl = TextEditingController();
  final _journalPathCtrl = TextEditingController();

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSettings();
    final controllers = [
      _titleCtrl, _authorFullNameCtrl, _authorOrcidCtrl,
      _authorAffiliationCtrl,
      _volumeCtrl, _issueCtrl,
      _articleIdCtrl, _submissionIdCtrl, _publicationIdCtrl, _issueViewIdCtrl,
      _pdfGalleyIdCtrl, _publishedDateCtrl, _submittedDateCtrl, _modifiedDateCtrl,
    ];
    for (final ctrl in controllers) {
      ctrl.addListener(_rebuild);
    }
    _authorBioQuill.addListener(_rebuild);
  }

  @override
  void dispose() {
    final controllers = [
      _titleCtrl, _authorFullNameCtrl, _authorOrcidCtrl,
      _authorAffiliationCtrl,
      _volumeCtrl, _issueCtrl,
      _articleIdCtrl, _submissionIdCtrl, _publicationIdCtrl, _issueViewIdCtrl,
      _pdfGalleyIdCtrl, _publishedDateCtrl, _submittedDateCtrl, _modifiedDateCtrl,
      _baseUrlCtrl, _journalPathCtrl,
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
      submittedDate: _submittedDateCtrl.text,
      modifiedDate: _modifiedDateCtrl.text,
      abstract_: _parsedMetadata?.abstract_ ?? '',
      keywords: _parsedMetadata?.keywords ?? '',
      articleBodyHtml: _parsedMetadata?.articleBodyHtml ?? '',
    );
  }

  JournalSettings get _currentSettings => JournalSettings(
    baseUrl: _baseUrlCtrl.text,
    journalPath: _journalPathCtrl.text,
  );

  // ── Settings persistence ──────────────────────────────────────────────────────
  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.load();
    setState(() {
      _baseUrlCtrl.text = settings.baseUrl;
      _journalPathCtrl.text = settings.journalPath;
    });
  }

  // ── PDF processing ────────────────────────────────────────────────────────────
  Future<void> _processFile(File file) async {
    setState(() => _selectedPdf = file);
    try {
      final metadata = await _pdfParser.parse(file);
      setState(() {
        _parsedMetadata = metadata;
        _titleCtrl.text = metadata.title.replaceAll(RegExp(r'[^\x00-\x7F\u00C0-\u017F\u0180-\u024F]'), "'");
        _authorFullNameCtrl.text = metadata.authorFullName;
        _authorOrcidCtrl.text = metadata.authorOrcid;
        _authorAffiliationCtrl.text = metadata.authorAffiliation;
        
        // Reset and populate Quill editor
        _authorBioQuill.document = Document()..insert(0, metadata.authorBio);
        
        _volumeCtrl.text = metadata.volume;
        _issueCtrl.text = metadata.issue;
        _articleIdCtrl.text = metadata.articleId;
        _submissionIdCtrl.text = metadata.submissionId;
        _publishedDateCtrl.text = metadata.publishedDate;
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

    final htmlContent = _htmlGenerator.buildHtml(metadata, settings);
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
                    submittedDateCtrl: _submittedDateCtrl,
                    modifiedDateCtrl: _modifiedDateCtrl,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: SettingsForm(
                    baseUrlCtrl: _baseUrlCtrl,
                    journalPathCtrl: _journalPathCtrl,
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
