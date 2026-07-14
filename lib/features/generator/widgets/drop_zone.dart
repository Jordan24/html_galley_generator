import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';

/// A drag-and-drop zone that accepts DOCX files.
///
/// Calls [onFilePicked] when a valid DOCX is dropped onto the widget.
class DropZone extends StatefulWidget {
  const DropZone({
    super.key,
    required this.selectedFile,
    required this.onFilePicked,
    this.isEnabled = true,
  });

  /// The currently loaded DOCX file, or null if none has been loaded.
  final File? selectedFile;

  /// Invoked with the dropped [File] when a DOCX is dropped.
  final ValueChanged<File> onFilePicked;

  /// Whether file uploading is enabled.
  final bool isEnabled;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isHovering = false;

  Future<void> _pickFile() async {
    if (!widget.isEnabled) return;
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'documents',
      extensions: <String>['docx'],
    );
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );
      if (file != null) {
        widget.onFilePicked(File(file.path));
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) {
        if (widget.isEnabled) {
          setState(() => _isHovering = true);
        }
      },
      onDragExited: (_) => setState(() => _isHovering = false),
      onDragDone: (details) {
        if (!widget.isEnabled) return;
        setState(() => _isHovering = false);
        if (details.files.isNotEmpty) {
          final file = File(details.files.first.path);
          final lowerPath = file.path.toLowerCase();
          if (lowerPath.endsWith('.docx')) {
            widget.onFilePicked(file);
          }
        }
      },
      child: MouseRegion(
        cursor: widget.isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: InkWell(
          onTap: widget.isEnabled ? _pickFile : null,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: !widget.isEnabled
                  ? const Color(0xFFF1F5F9)
                  : _isHovering
                      ? const Color(0xFFF2F4F6)
                      : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: !widget.isEnabled
                    ? const Color(0xFFE2E8F0)
                    : _isHovering
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isEnabled ? Icons.upload_file : Icons.lock_outline,
                    size: 48,
                    color: widget.isEnabled
                        ? Colors.blueGrey[400]
                        : Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Builder(
                      builder: (context) {
                        if (!widget.isEnabled) {
                          return const Text(
                            'Journal Settings required: Please fill in Journal Base URL and Journal Path under Journal Settings to enable DOCX upload.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFFE11D48),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }

                        return Text.rich(
                          TextSpan(
                            text: widget.selectedFile != null
                                ? 'Loaded: ${widget.selectedFile!.path.split(Platform.pathSeparator).last}'
                                : 'Drag and drop DOCX to start, or ',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blueGrey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              if (widget.selectedFile == null) ...[
                                const TextSpan(
                                  text: 'click to browse',
                                  style: TextStyle(
                                    color: Color(0xFF1D2B3E),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ],
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),
                  if (widget.isEnabled && widget.selectedFile != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Drag a new file or click here to browse',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey[500]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
