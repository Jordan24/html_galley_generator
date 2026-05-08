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
    required this.publicationIdCtrl,
    required this.issueViewIdCtrl,
    required this.pdfGalleyIdCtrl,
    required this.publishedDateCtrl,
    required this.issuedDateCtrl,
    required this.publishedDateMonYYYYCtrl,
    required this.publishYearCtrl,
    required this.submittedDateCtrl,
    required this.modifiedDateCtrl,
    required this.articleBibliographyCtrl,
    required this.articleFootnotesCtrl,
    required this.titleMainCtrl,
    required this.issueIdCtrl,
    required this.abstractCtrl,
    required this.keywordsCtrl,
    required this.articleBodyHtmlCtrl,
  });

  final TextEditingController titleCtrl;
  final TextEditingController volumeCtrl;
  final TextEditingController issueCtrl;
  final TextEditingController articleIdCtrl;
  final TextEditingController submissionIdCtrl;
  final TextEditingController publicationIdCtrl;
  final TextEditingController issueViewIdCtrl;
  final TextEditingController pdfGalleyIdCtrl;
  final TextEditingController publishedDateCtrl;
  final TextEditingController issuedDateCtrl;
  final TextEditingController publishedDateMonYYYYCtrl;
  final TextEditingController publishYearCtrl;
  final TextEditingController submittedDateCtrl;
  final TextEditingController modifiedDateCtrl;
  final TextEditingController articleBibliographyCtrl;
  final TextEditingController articleFootnotesCtrl;
  final TextEditingController titleMainCtrl;
  final TextEditingController issueIdCtrl;
  final TextEditingController abstractCtrl;
  final TextEditingController keywordsCtrl;
  final TextEditingController articleBodyHtmlCtrl;

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
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Issue ID',
                    controller: issueIdCtrl,
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
                    label: 'Publication ID',
                    controller: publicationIdCtrl,
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
              label: 'Article Bibliography (HTML)',
              controller: articleBibliographyCtrl,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Article Footnotes (HTML)',
              controller: articleFootnotesCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Abstract',
              controller: abstractCtrl,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Keywords',
              controller: keywordsCtrl,
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Article Body (HTML)',
              controller: articleBodyHtmlCtrl,
              maxLines: 15,
            ),
          ],
        ),
      ),
    );
  }
}
