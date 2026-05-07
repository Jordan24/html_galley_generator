import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/orcid_service.dart';
import 'labeled_text_field.dart';

/// Card displaying the article metadata form fields.
class MetadataForm extends StatefulWidget {
  const MetadataForm({
    super.key,
    required this.titleCtrl,
    required this.authorFullNameCtrl,
    required this.authorOrcidCtrl,
    required this.authorAffiliationCtrl,
    required this.authorBioQuill,
    required this.volumeCtrl,
    required this.issueCtrl,
    required this.articleIdCtrl,
    required this.submissionIdCtrl,
    required this.publicationIdCtrl,
    required this.issueViewIdCtrl,
    required this.pdfGalleyIdCtrl,
    required this.publishedDateCtrl,
    required this.submittedDateCtrl,
    required this.modifiedDateCtrl,
  });

  final TextEditingController titleCtrl;
  final TextEditingController authorFullNameCtrl;
  final TextEditingController authorOrcidCtrl;
  final TextEditingController authorAffiliationCtrl;
  final QuillController authorBioQuill;
  final TextEditingController volumeCtrl;
  final TextEditingController issueCtrl;
  final TextEditingController articleIdCtrl;
  final TextEditingController submissionIdCtrl;
  final TextEditingController publicationIdCtrl;
  final TextEditingController issueViewIdCtrl;
  final TextEditingController pdfGalleyIdCtrl;
  final TextEditingController publishedDateCtrl;
  final TextEditingController submittedDateCtrl;
  final TextEditingController modifiedDateCtrl;

  @override
  State<MetadataForm> createState() => _MetadataFormState();
}

class _MetadataFormState extends State<MetadataForm> {
  final _orcidService = OrcidService();
  bool _isSearchingOrcid = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger lookup when name is populated if ORCID is empty
    widget.authorFullNameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    widget.authorFullNameCtrl.removeListener(_onNameChanged);
    super.dispose();
  }

  void _onNameChanged() {
    if (!_isSearchingOrcid &&
        widget.authorFullNameCtrl.text.isNotEmpty &&
        widget.authorOrcidCtrl.text.isEmpty) {
      // Small delay to allow PDF parsing to finish populating other fields
      // or to avoid immediate triggers while typing
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted &&
            !_isSearchingOrcid &&
            widget.authorFullNameCtrl.text.isNotEmpty &&
            widget.authorOrcidCtrl.text.isEmpty) {
          _lookupOrcid();
        }
      });
    }
  }

  Future<void> _lookupOrcid() async {
    if (widget.authorFullNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an author name first.')),
      );
      return;
    }

    setState(() => _isSearchingOrcid = true);
    try {
      // Clean name and affiliation of common PDF artifacts
      final cleanName = widget.authorFullNameCtrl.text
          .replaceAll(RegExp(r'[\d\*†‡§¶#]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final cleanAff = widget.authorAffiliationCtrl.text
          .replaceAll(RegExp(r'[\*†‡§¶#]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final result = await _orcidService.findOrcid(
        cleanName,
        affiliation: cleanAff,
      );

      if (result != null) {
        widget.authorOrcidCtrl.text = result;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ORCID found and populated!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No ORCID found for "$cleanName" at "$cleanAff".'),
            action: SnackBarAction(
              label: 'Search Web',
              onPressed: () {
                final query = Uri.encodeComponent(
                  'text:"$cleanName" AND affiliation-org-name:"$cleanAff"',
                );
                final url = Uri.parse(
                  'https://orcid.org/orcid-search/search?searchQuery=$query',
                );
                launchUrl(url);
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Search failed: $e. If on web, this may be a CORS restriction.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSearchingOrcid = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Article Metadata',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            LabeledTextField(
              label: 'Article Title',
              controller: widget.titleCtrl,
            ),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Author Full Name',
                    controller: widget.authorFullNameCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Author ORCID',
                    controller: widget.authorOrcidCtrl,
                    suffix: _isSearchingOrcid
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : ValueListenableBuilder<TextEditingValue>(
                            valueListenable: widget.authorOrcidCtrl,
                            builder: (context, value, _) {
                              final orcid = value.text.trim();
                              if (orcid.isEmpty) {
                                return IconButton(
                                  icon: const Icon(Icons.search, size: 20),
                                  tooltip: 'Search ORCID online',
                                  onPressed: _lookupOrcid,
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    final url = Uri.parse(
                                      'https://orcid.org/$orcid',
                                    );
                                    launchUrl(url);
                                  },
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFA6CE39),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'iD',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
            LabeledTextField(
              label: 'Author Affiliation',
              controller: widget.authorAffiliationCtrl,
            ),
            const SizedBox(height: 16),
            const Text(
              'Author Bio',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  QuillSimpleToolbar(
                    controller: widget.authorBioQuill,
                    config: const QuillSimpleToolbarConfig(
                      showListNumbers: false,
                      showListBullets: false,
                      showCodeBlock: false,
                      showQuote: false,
                      showAlignmentButtons: false,
                      showLink: false,
                      showUndo: false,
                      showRedo: false,
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: false,
                      showStrikeThrough: false,
                      showColorButton: false,
                      showBackgroundColorButton: false,
                      showClearFormat: false,
                      showFontFamily: false,
                      showFontSize: false,
                      showSubscript: false,
                      showSuperscript: false,
                      showSearchButton: false,
                      showIndent: false,
                      showInlineCode: false,
                      showListCheck: false,
                      showHeaderStyle: false,
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFCBD5E1),
                  ),
                  Container(
                    height: 150,
                    padding: const EdgeInsets.all(12),
                    child: QuillEditor.basic(
                      controller: widget.authorBioQuill,
                      config: const QuillEditorConfig(
                        placeholder: 'Enter author biography here...',
                        padding: EdgeInsets.zero,
                        expands: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Volume',
                    controller: widget.volumeCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Issue',
                    controller: widget.issueCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Article ID',
                    controller: widget.articleIdCtrl,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Submission ID',
                    controller: widget.submissionIdCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Publication ID',
                    controller: widget.publicationIdCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Issue View ID',
                    controller: widget.issueViewIdCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'PDF Galley ID',
                    controller: widget.pdfGalleyIdCtrl,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Published Date (YYYY-MM-DD)',
                    controller: widget.publishedDateCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Submitted Date (YYYY-MM-DD)',
                    controller: widget.submittedDateCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Modified Date (YYYY-MM-DD)',
                    controller: widget.modifiedDateCtrl,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
