import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart' as vsc;

import '../models/article_metadata.dart';
import '../models/journal_settings.dart';
import '../services/html_generator_service.dart';

class EditorScreen extends StatefulWidget {
  final ArticleMetadata metadata;
  final JournalSettings settings;

  const EditorScreen({
    super.key,
    required this.metadata,
    required this.settings,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late QuillController _controller;
  final _htmlGenerator = HtmlGeneratorService();
  bool _isSaving = false;
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  QuillController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final html = await _htmlGenerator.buildArticleMain(
        widget.metadata,
        widget.settings,
      );
      final delta = HtmlToDelta().convert(html);
      setState(() {
        _controller = QuillController(
          document: Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading content: $e');
      setState(() {
        _controller = QuillController.basic();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final deltaJson = _controller.document.toDelta().toJson();
      final converter = vsc.QuillDeltaToHtmlConverter(
        List<Map<String, dynamic>>.from(deltaJson),
        vsc.ConverterOptions.forEmail(),
      );
      final editedHtml = converter.convert();

      final fullHtml = await _htmlGenerator.buildFullHtml(
        editedHtml,
        widget.metadata,
        widget.settings,
      );

      final suggestedName = _htmlGenerator.buildFileName(widget.metadata);
      final saveLocation = await getSaveLocation(suggestedName: suggestedName);

      if (saveLocation != null) {
        await File(saveLocation.path).writeAsString(fullHtml);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('HTML Galley saved successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    if (!_isLoading) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light blue-grey background
      appBar: AppBar(
        title: const Text(
          'Edit HTML Galley',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF334155),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Galley'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D2B3E), // Matching theme
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  child: QuillSimpleToolbar(
                    controller: _controller,
                    config: const QuillSimpleToolbarConfig(
                      multiRowsDisplay: false,
                      showUndo: true,
                      showRedo: true,
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: true,
                      showStrikeThrough: true,
                      showColorButton: true,
                      showBackgroundColorButton: true,
                      showListNumbers: true,
                      showListBullets: true,
                      showListCheck: false,
                      showCodeBlock: true,
                      showQuote: true,
                      showIndent: true,
                      showLink: true,
                      showDirection: false,
                      showSearchButton: true,
                      showSubscript: false,
                      showSuperscript: false,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 20,
                    ),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 900),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(60),
                        child: CallbackShortcuts(
                          bindings: {
                            // Bold: Ctrl+B and Cmd+B
                            const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
                              _controller.formatSelection(Attribute.bold);
                            },
                            const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
                              _controller.formatSelection(Attribute.bold);
                            },
                            // Italic: Ctrl+I and Cmd+I
                            const SingleActivator(LogicalKeyboardKey.keyI, control: true): () {
                              _controller.formatSelection(Attribute.italic);
                            },
                            const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () {
                              _controller.formatSelection(Attribute.italic);
                            },
                            // Underline: Ctrl+U and Cmd+U
                            const SingleActivator(LogicalKeyboardKey.keyU, control: true): () {
                              _controller.formatSelection(Attribute.underline);
                            },
                            const SingleActivator(LogicalKeyboardKey.keyU, meta: true): () {
                              _controller.formatSelection(Attribute.underline);
                            },
                            // Strikethrough: Ctrl+Shift+X and Cmd+Shift+X
                            const SingleActivator(LogicalKeyboardKey.keyX, control: true, shift: true): () {
                              _controller.formatSelection(Attribute.strikeThrough);
                            },
                            const SingleActivator(LogicalKeyboardKey.keyX, meta: true, shift: true): () {
                              _controller.formatSelection(Attribute.strikeThrough);
                            },
                          },
                          child: QuillEditor.basic(
                            controller: _controller,
                            config: QuillEditorConfig(
                              padding: EdgeInsets.zero,
                              autoFocus: true,
                              expands: true,
                              scrollable: true,
                              embedBuilders: [
                                QuillImageEmbedBuilder(),
                              ],
                              customStyles: DefaultStyles(
                                h1: DefaultTextBlockStyle(
                                  const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D2B3E),
                                    height: 1.2,
                                  ),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(24, 16),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                h2: DefaultTextBlockStyle(
                                  const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D2B3E),
                                    height: 1.2,
                                  ),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(20, 12),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                h3: DefaultTextBlockStyle(
                                  const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D2B3E),
                                    height: 1.2,
                                  ),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(16, 8),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                                paragraph: DefaultTextBlockStyle(
                                  const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF334155),
                                    height: 1.6,
                                  ),
                                  const HorizontalSpacing(0, 0),
                                  const VerticalSpacing(8, 8),
                                  const VerticalSpacing(0, 0),
                                  null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class QuillImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final String data = embedContext.node.value.data;
    
    Widget imageWidget;
    if (data.startsWith('data:image/')) {
      try {
        final commaIndex = data.indexOf(',');
        if (commaIndex != -1) {
          final base64Str = data.substring(commaIndex + 1);
          final bytes = base64Decode(base64Str.trim());
          imageWidget = Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, size: 60, color: Colors.grey);
            },
          );
        } else {
          imageWidget = const Icon(Icons.broken_image, size: 60, color: Colors.grey);
        }
      } catch (e) {
        imageWidget = const Icon(Icons.broken_image, size: 60, color: Colors.grey);
      }
    } else if (data.startsWith('http://') || data.startsWith('https://')) {
      imageWidget = Image.network(
        data,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.broken_image, size: 60, color: Colors.grey);
        },
      );
    } else {
      // Local file or path
      try {
        final uri = Uri.parse(data);
        final file = File(uri.isAbsolute ? uri.toFilePath() : data);
        if (file.existsSync()) {
          imageWidget = Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, size: 60, color: Colors.grey);
            },
          );
        } else {
          imageWidget = const Icon(Icons.broken_image, size: 60, color: Colors.grey);
        }
      } catch (_) {
        imageWidget = const Icon(Icons.broken_image, size: 60, color: Colors.grey);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 600,
            maxHeight: 400,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageWidget,
        ),
      ),
    );
  }

  @override
  String toPlainText(Embed node) {
    return '[Image]';
  }
}
