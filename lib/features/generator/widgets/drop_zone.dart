import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

/// A drag-and-drop zone that accepts PDF files.
///
/// Calls [onFilePicked] when a valid PDF is dropped onto the widget.
class DropZone extends StatefulWidget {
  const DropZone({
    super.key,
    required this.selectedPdf,
    required this.onFilePicked,
  });

  /// The currently loaded PDF file, or null if none has been loaded.
  final File? selectedPdf;

  /// Invoked with the dropped [File] when a PDF is dropped.
  final ValueChanged<File> onFilePicked;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isHovering = true),
      onDragExited: (_) => setState(() => _isHovering = false),
      onDragDone: (details) {
        setState(() => _isHovering = false);
        if (details.files.isNotEmpty) {
          final file = File(details.files.first.path);
          if (file.path.toLowerCase().endsWith('.pdf')) {
            widget.onFilePicked(file);
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: _isHovering ? const Color(0xFFF2F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                _isHovering ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, size: 48, color: Colors.blueGrey[400]),
            const SizedBox(height: 16),
            Text(
              widget.selectedPdf != null
                  ? 'Loaded: ${widget.selectedPdf!.path.split(Platform.pathSeparator).last}'
                  : 'Drag and drop PDF to start',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blueGrey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
