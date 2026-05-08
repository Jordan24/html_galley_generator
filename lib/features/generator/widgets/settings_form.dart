import 'package:flutter/material.dart';
import 'labeled_text_field.dart';

class SettingsForm extends StatelessWidget {
  const SettingsForm({
    super.key,
    required this.journalBaseUrlCtrl,
    required this.journalPathCtrl,
    required this.journalNameCtrl,
    required this.journalAbbrevCtrl,
    required this.journalIssnCtrl,
    required this.journalDoiIdCtrl,
    required this.journalOrganizationUrlCtrl,
    required this.supportingOrganizationCtrl,
  });

  final TextEditingController journalBaseUrlCtrl;
  final TextEditingController journalPathCtrl;
  final TextEditingController journalNameCtrl;
  final TextEditingController journalAbbrevCtrl;
  final TextEditingController journalIssnCtrl;
  final TextEditingController journalDoiIdCtrl;
  final TextEditingController journalOrganizationUrlCtrl;
  final TextEditingController supportingOrganizationCtrl;

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
              controller: journalBaseUrlCtrl,
            ),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Journal Path',
                    controller: journalPathCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'Abbreviation',
                    controller: journalAbbrevCtrl,
                  ),
                ),
              ],
            ),
            LabeledTextField(
              label: 'Journal Name',
              controller: journalNameCtrl,
            ),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'ISSN',
                    controller: journalIssnCtrl,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LabeledTextField(
                    label: 'DOI Prefix',
                    controller: journalDoiIdCtrl,
                  ),
                ),
              ],
            ),
            LabeledTextField(
              label: 'Organization URL',
              controller: journalOrganizationUrlCtrl,
            ),
            LabeledTextField(
              label: 'Supporting Organization',
              controller: supportingOrganizationCtrl,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
