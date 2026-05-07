import 'package:flutter/material.dart';
import 'labeled_text_field.dart';

/// Card displaying the journal-level settings fields.
class SettingsForm extends StatelessWidget {
  const SettingsForm({
    super.key,
    required this.baseUrlCtrl,
    required this.journalPathCtrl,
  });

  final TextEditingController baseUrlCtrl;
  final TextEditingController journalPathCtrl;

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
              'Journal Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            LabeledTextField(
              label: 'Journal Base URL',
              controller: baseUrlCtrl,
            ),
            LabeledTextField(
              label: 'Journal Path (e.g., ta)',
              controller: journalPathCtrl,
            ),
          ],
        ),
      ),
    );
  }
}
