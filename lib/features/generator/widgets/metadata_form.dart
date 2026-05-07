import 'package:flutter/material.dart';
import 'labeled_text_field.dart';

/// Card displaying the article metadata form fields.
class MetadataForm extends StatelessWidget {
  const MetadataForm({
    super.key,
    required this.titleCtrl,
    required this.authorCtrl,
    required this.volumeCtrl,
    required this.issueCtrl,
    required this.articleIdCtrl,
  });

  final TextEditingController titleCtrl;
  final TextEditingController authorCtrl;
  final TextEditingController volumeCtrl;
  final TextEditingController issueCtrl;
  final TextEditingController articleIdCtrl;

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
            LabeledTextField(label: 'Title', controller: titleCtrl),
            LabeledTextField(
              label: 'Author(s) (e.g., COLLINS)',
              controller: authorCtrl,
            ),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Volume',
                    controller: volumeCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Issue',
                    controller: issueCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Article ID',
                    controller: articleIdCtrl,
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
