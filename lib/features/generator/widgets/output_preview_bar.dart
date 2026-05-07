import 'package:flutter/material.dart';

/// Displays the previewed output filename and the generate button.
class OutputPreviewBar extends StatelessWidget {
  const OutputPreviewBar({
    super.key,
    required this.fileName,
    required this.onGenerate,
  });

  /// The suggested filename computed from the current form values.
  final String fileName;

  /// Called when the user taps "Generate HTML Galley".
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
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
            onPressed: onGenerate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D2B3E),
              foregroundColor: Colors.white,
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
    );
  }
}
