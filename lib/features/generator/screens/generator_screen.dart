import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

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
  final _authorCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _articleIdCtrl = TextEditingController();

  // Settings controllers
  final _baseUrlCtrl = TextEditingController();
  final _journalPathCtrl = TextEditingController();

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSettings();
    for (final ctrl in [_titleCtrl, _authorCtrl, _volumeCtrl, _issueCtrl]) {
      ctrl.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    for (final ctrl in [
      _titleCtrl,
      _authorCtrl,
      _volumeCtrl,
      _issueCtrl,
      _articleIdCtrl,
      _baseUrlCtrl,
      _journalPathCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _rebuild() => setState(() {});

  ArticleMetadata get _currentMetadata => ArticleMetadata(
    title: _titleCtrl.text,
    author: _authorCtrl.text,
    volume: _volumeCtrl.text,
    issue: _issueCtrl.text,
    articleId: _articleIdCtrl.text,
  );

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
        _titleCtrl.text = metadata.title;
        _authorCtrl.text = metadata.author;
        _volumeCtrl.text = metadata.volume;
        _issueCtrl.text = metadata.issue;
        _articleIdCtrl.text = metadata.articleId;
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
                    authorCtrl: _authorCtrl,
                    volumeCtrl: _volumeCtrl,
                    issueCtrl: _issueCtrl,
                    articleIdCtrl: _articleIdCtrl,
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
