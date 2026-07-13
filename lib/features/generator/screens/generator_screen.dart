import 'package:flutter/material.dart';

import '../controllers/generator_controller.dart';
import '../services/docx_parser_service.dart';
import '../services/pdf_parser_service.dart';
import '../widgets/article_metadata_form.dart';
import '../widgets/author_metadata_form.dart';
import '../widgets/drop_zone.dart';
import '../widgets/output_preview_bar.dart';
import '../widgets/settings_form.dart';
import 'editor_screen.dart';

/// The main screen of the application. Renders forms and hooks up events
/// to the [GeneratorController] for document ingestion and state updates.
class GeneratorScreen extends StatefulWidget {
  final DocxParserService? docxParser;
  final PdfParserService? pdfParser;

  const GeneratorScreen({
    super.key,
    this.docxParser,
    this.pdfParser,
  });

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  late final GeneratorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GeneratorController(
      docxParser: widget.docxParser,
      pdfParser: widget.pdfParser,
    );
    _controller.loadSettings();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateHtml() async {
    final metadata = _controller.currentMetadata;
    final settings = _controller.currentSettings;

    if (metadata.articleId.isEmpty) {
      _showSnackBar('Please provide an Article ID.');
      return;
    }

    await _controller.settingsRepo.save(settings);

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
    final metadata = _controller.currentMetadata;
    final fileName = _controller.htmlGenerator.buildFileName(metadata);

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
                DropZone(
                  selectedPdf: _controller.selectedPdf,
                  onFilePicked: (file) => _controller.processFile(
                    file,
                    onStatus: _showSnackBar,
                  ),
                ),
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
      authorFullNameCtrl: _controller.authorFullNameCtrl,
      authorFirstNameCtrl: _controller.authorFirstNameCtrl,
      authorLastNameCtrl: _controller.authorLastNameCtrl,
      authorOrcidCtrl: _controller.authorOrcidCtrl,
      authorAffiliationCtrl: _controller.authorAffiliationCtrl,
      authorBioQuill: _controller.authorBioQuill,
    );

    final articleForm = ArticleMetadataForm(
      titleCtrl: _controller.titleCtrl,
      volumeCtrl: _controller.volumeCtrl,
      issueCtrl: _controller.issueCtrl,
      articleIdCtrl: _controller.articleIdCtrl,
      submissionIdCtrl: _controller.submissionIdCtrl,
      publicationIdCtrl: _controller.publicationIdCtrl,
      issueViewIdCtrl: _controller.issueViewIdCtrl,
      pdfGalleyIdCtrl: _controller.pdfGalleyIdCtrl,
      publishedDateCtrl: _controller.publishedDateCtrl,
      issuedDateCtrl: _controller.issuedDateCtrl,
      publishedDateMonYYYYCtrl: _controller.publishedDateMonYYYYCtrl,
      publishYearCtrl: _controller.publishYearCtrl,
      submittedDateCtrl: _controller.submittedDateCtrl,
      modifiedDateCtrl: _controller.modifiedDateCtrl,
      titleMainCtrl: _controller.titleMainCtrl,
      keywordsCtrl: _controller.keywordsCtrl,
      articleBodyCtrl: _controller.articleBodyCtrl,
    );

    final settingsForm = SettingsForm(
      journalBaseUrlCtrl: _controller.journalBaseUrlCtrl,
      journalPathCtrl: _controller.journalPathCtrl,
      journalNameCtrl: _controller.journalNameCtrl,
      journalAbbrevCtrl: _controller.journalAbbrevCtrl,
      journalIssnCtrl: _controller.journalIssnCtrl,
      journalDoiIdCtrl: _controller.journalDoiIdCtrl,
      journalOrganizationUrlCtrl: _controller.journalOrganizationUrlCtrl,
      supportingOrganizationCtrl: _controller.supportingOrganizationCtrl,
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
