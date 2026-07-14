import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/onboarding_dialog.dart';
import '../controllers/generator_controller.dart';
import '../services/docx_parser_service.dart';
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

  const GeneratorScreen({
    super.key,
    this.docxParser,
  });

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  late final GeneratorController _controller;

  // Public getter for testing
  GeneratorController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller = GeneratorController(
      docxParser: widget.docxParser,
    );
    _controller.loadSettings();
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboarding();
    });
  }

  Future<void> _checkAndShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('hasShownOnboarding') ?? false;
    if (!hasShown && mounted) {
      _showOnboardingDialog();
    }
  }

  void _showOnboardingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const OnboardingDialog(),
    );
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

    final List<String> missingFields = [];
    if (_controller.selectedFile == null) missingFields.add('DOCX File');
    if (settings.journalName.trim().isEmpty) missingFields.add('Journal Name');
    if (settings.journalBaseUrl.trim().isEmpty) missingFields.add('Journal Base URL');
    if (settings.journalPath.trim().isEmpty) missingFields.add('Journal Path');
    if (metadata.title.trim().isEmpty) missingFields.add('Article Title');
    if (metadata.authorFullName.trim().isEmpty) missingFields.add('Author Full Name');
    if (metadata.volume.trim().isEmpty) missingFields.add('Volume');
    if (metadata.issue.trim().isEmpty) missingFields.add('Issue');
    if (metadata.articleId.trim().isEmpty) missingFields.add('Article ID');
    if (metadata.publicationId.trim().isEmpty) missingFields.add('Publication ID');
    if (metadata.issueViewId.trim().isEmpty) missingFields.add('Issue View ID');
    if (metadata.pdfGalleyId.trim().isEmpty) missingFields.add('PDF Galley ID');
    if (metadata.publishedDate.trim().isEmpty) missingFields.add('Published Date (ISO)');
    if (metadata.publishedDateMonYYYY.trim().isEmpty) missingFields.add('Date (Mon YYYY)');
    if (metadata.publishYear.trim().isEmpty) missingFields.add('Year');

    if (missingFields.isNotEmpty) {
      _showSnackBar('Please fill in all required fields: ${missingFields.join(', ')}');
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
    final settings = _controller.currentSettings;
    final fileName = _controller.htmlGenerator.buildFileName(metadata);

    final isUploadEnabled = settings.journalBaseUrl.trim().isNotEmpty &&
        settings.journalPath.trim().isNotEmpty;

    final List<String> missingFields = [];
    if (_controller.selectedFile == null) {
      missingFields.add('DOCX File');
    }
    if (settings.journalName.trim().isEmpty) {
      missingFields.add('Journal Name');
    }
    if (settings.journalBaseUrl.trim().isEmpty) {
      missingFields.add('Journal Base URL');
    }
    if (settings.journalPath.trim().isEmpty) {
      missingFields.add('Journal Path');
    }
    if (metadata.title.trim().isEmpty) {
      missingFields.add('Article Title');
    }
    if (metadata.authorFullName.trim().isEmpty) {
      missingFields.add('Author Full Name');
    }
    if (metadata.volume.trim().isEmpty) {
      missingFields.add('Volume');
    }
    if (metadata.issue.trim().isEmpty) {
      missingFields.add('Issue');
    }
    if (metadata.articleId.trim().isEmpty) {
      missingFields.add('Article ID');
    }
    if (metadata.publicationId.trim().isEmpty) {
      missingFields.add('Publication ID');
    }
    if (metadata.issueViewId.trim().isEmpty) {
      missingFields.add('Issue View ID');
    }
    if (metadata.pdfGalleyId.trim().isEmpty) {
      missingFields.add('PDF Galley ID');
    }
    if (metadata.publishedDate.trim().isEmpty) {
      missingFields.add('Published Date (ISO)');
    }
    if (metadata.publishedDateMonYYYY.trim().isEmpty) {
      missingFields.add('Date (Mon YYYY)');
    }
    if (metadata.publishYear.trim().isEmpty) {
      missingFields.add('Year');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text(
          'OJS HTML Galley Generator',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'How to Use & Tips',
            onPressed: _showOnboardingDialog,
          ),
          const SizedBox(width: 16),
        ],
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
                  selectedFile: _controller.selectedFile,
                  isEnabled: isUploadEnabled,
                  onFilePicked: (file) => _controller.processFile(
                    file,
                    onStatus: _showSnackBar,
                  ),
                ),
                const SizedBox(height: 32),
                OutputPreviewBar(
                  fileName: fileName,
                  onGenerate: _generateHtml,
                  isFileUploaded: _controller.selectedFile != null,
                  missingFields: missingFields,
                ),
                const SizedBox(height: 32),
                _buildFormLayout(isWide, isMedium),
                const SizedBox(height: 48),
                const Divider(),
                _buildFooter(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 24,
          runSpacing: 12,
          children: [
            _buildFooterLink(
              label: 'OPEN SOURCE CODE',
              url: 'https://github.com/Jordan24/html_galley_generator',
            ),
            const Text(
              '•',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            _buildFooterLink(
              label: 'MIT License',
              url: 'https://opensource.org/licenses/MIT',
            ),
            const Text(
              '•',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            _buildFooterLink(
              label: '☕ Buy me a coffee',
              url: 'https://buymeacoffee.com/thejambers',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLink({required String label, required String url}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.parse(url);
          try {
            await launchUrl(uri);
          } catch (e) {
            _showSnackBar('Could not launch URL: $url');
          }
        },
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildFormLayout(bool isWide, bool isMedium) {
    final isFileUploaded = _controller.selectedFile != null;

    final authorForm = AuthorMetadataForm(
      authorFullNameCtrl: _controller.authorFullNameCtrl,
      authorFirstNameCtrl: _controller.authorFirstNameCtrl,
      authorLastNameCtrl: _controller.authorLastNameCtrl,
      authorOrcidCtrl: _controller.authorOrcidCtrl,
      authorAffiliationCtrl: _controller.authorAffiliationCtrl,
      authorBioQuill: _controller.authorBioQuill,
      isEnabled: isFileUploaded,
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
      isEnabled: isFileUploaded,
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
      // 3 Columns: Journal | Author | Article
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: settingsForm),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: authorForm),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: articleForm),
        ],
      );
    } else if (isMedium) {
      // 2 Columns: [Journal + Author] | Article
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [settingsForm, const SizedBox(height: 24), authorForm],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: articleForm),
        ],
      );
    } else {
      // 1 Column: Journal -> Author -> Article
      return Column(
        children: [
          settingsForm,
          const SizedBox(height: 24),
          authorForm,
          const SizedBox(height: 24),
          articleForm,
        ],
      );
    }
  }
}
