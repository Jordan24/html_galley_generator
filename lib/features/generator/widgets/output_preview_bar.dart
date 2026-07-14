import 'package:flutter/material.dart';

/// Displays the previewed output filename and the generate button.
class OutputPreviewBar extends StatelessWidget {
  const OutputPreviewBar({
    super.key,
    required this.fileName,
    required this.onGenerate,
    required this.isFileUploaded,
    this.missingFields = const [],
  });

  /// The suggested filename computed from the current form values.
  final String fileName;

  /// Called when the user taps "Generate HTML Galley".
  final VoidCallback onGenerate;

  /// List of missing required fields.
  final List<String> missingFields;

  /// Whether a DOCX file is currently loaded/uploaded.
  final bool isFileUploaded;

  @override
  Widget build(BuildContext context) {
    final hasMissing = missingFields.isNotEmpty;
    final showWarningBanner = isFileUploaded && hasMissing;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Output Filename Preview',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'monospace',
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: hasMissing ? null : onGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D2B3E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Generate HTML Galley'),
              ),
            ],
          ),
          if (showWarningBanner) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To enable generation, please fill in all required fields: ${missingFields.join(', ')}.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFE11D48),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
