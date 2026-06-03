import 'package:flutter/material.dart';
import 'labeled_text_field.dart';

class ArticleMetadataForm extends StatelessWidget {
  const ArticleMetadataForm({
    super.key,
    required this.titleCtrl,
    required this.volumeCtrl,
    required this.issueCtrl,
    required this.articleIdCtrl,
    required this.submissionIdCtrl,
    required this.issueViewIdCtrl,
    required this.pdfGalleyIdCtrl,
    required this.publishedDateCtrl,
    required this.issuedDateCtrl,
    required this.publishedDateMonYYYYCtrl,
    required this.publishYearCtrl,
    required this.submittedDateCtrl,
    required this.modifiedDateCtrl,
    required this.titleMainCtrl,
    required this.keywordsCtrl,
    required this.articleBodyCtrl,
  });

  final TextEditingController titleCtrl;
  final TextEditingController volumeCtrl;
  final TextEditingController issueCtrl;
  final TextEditingController articleIdCtrl;
  final TextEditingController submissionIdCtrl;
  final TextEditingController issueViewIdCtrl;
  final TextEditingController pdfGalleyIdCtrl;
  final TextEditingController publishedDateCtrl;
  final TextEditingController issuedDateCtrl;
  final TextEditingController publishedDateMonYYYYCtrl;
  final TextEditingController publishYearCtrl;
  final TextEditingController submittedDateCtrl;
  final TextEditingController modifiedDateCtrl;
  final TextEditingController titleMainCtrl;
  final TextEditingController keywordsCtrl;
  final TextEditingController articleBodyCtrl;

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
              controller: titleCtrl,
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
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Submission ID',
                    controller: submissionIdCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Issue View ID',
                    controller: issueViewIdCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'PDF Galley ID',
                    controller: pdfGalleyIdCtrl,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Published (ISO)',
                    controller: publishedDateCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Issued (ISO)',
                    controller: issuedDateCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Date (Mon YYYY)',
                    controller: publishedDateMonYYYYCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Year',
                    controller: publishYearCtrl,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Submitted Date',
                    controller: submittedDateCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Modified Date',
                    controller: modifiedDateCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Title Main',
                    controller: titleMainCtrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Keywords (comma-separated)',
              controller: keywordsCtrl,
            ),
            const SizedBox(height: 16),
            if (articleBodyCtrl.text.length > 50000)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Article Body (HTML)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'HTML content loaded: ${(articleBodyCtrl.text.length / 1024 / 1024).toStringAsFixed(2)} MB.\n'
                      'Direct HTML editing is disabled in the form for performance. '
                      'Use the rich text editor to view and edit the content.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              )
            else
              LabeledTextField(
                label: 'Article Body (HTML)',
                controller: articleBodyCtrl,
                maxLines: 25,
              ),
          ],
        ),
      ),
    );
  }
}
