import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/orcid_service.dart';
import 'labeled_text_field.dart';

class AuthorMetadataForm extends StatefulWidget {
  const AuthorMetadataForm({
    super.key,
    required this.authorFullNameCtrl,
    required this.authorFirstNameCtrl,
    required this.authorLastNameCtrl,
    required this.authorOrcidCtrl,
    required this.authorAffiliationCtrl,
    required this.authorBioQuill,
    this.isEnabled = true,
  });

  final TextEditingController authorFullNameCtrl;
  final TextEditingController authorFirstNameCtrl;
  final TextEditingController authorLastNameCtrl;
  final TextEditingController authorOrcidCtrl;
  final TextEditingController authorAffiliationCtrl;
  final QuillController authorBioQuill;
  final bool isEnabled;

  @override
  State<AuthorMetadataForm> createState() => _AuthorMetadataFormState();
}

class _AuthorMetadataFormState extends State<AuthorMetadataForm> {
  final _orcidService = OrcidService();
  bool _isSearchingOrcid = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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

      if (!mounted) return;

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
      child: IgnorePointer(
        ignoring: !widget.isEnabled,
        child: Opacity(
          opacity: widget.isEnabled ? 1.0 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Author Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            LabeledTextField(
              label: 'Full Name',
              controller: widget.authorFullNameCtrl,
              isRequired: true,
            ),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'First Name',
                    controller: widget.authorFirstNameCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Last Name',
                    controller: widget.authorLastNameCtrl,
                  ),
                ),
              ],
            ),
            LabeledTextField(
              label: 'ORCID',
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
            LabeledTextField(
              label: 'Affiliation',
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
                    height: 100,
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
          ],
        ),
      ),
    ),
  ),
);
  }
}
