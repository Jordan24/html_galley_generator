import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html_galley_generator/features/generator/screens/generator_screen.dart';
import 'package:html_galley_generator/features/generator/widgets/drop_zone.dart';
import 'package:html_galley_generator/features/generator/widgets/labeled_text_field.dart';
import 'package:html_galley_generator/features/generator/services/docx_parser_service.dart';
import 'package:html_galley_generator/features/generator/models/article_metadata.dart';

class FakeDocxParser extends Fake implements DocxParserService {
  @override
  Future<ArticleMetadata> parse(File file) async {
    return ArticleMetadata(
      title: 'Transnational Politics and Korean Evangelicalism: Affective Infrastructure and History',
      author: 'NOH',
      authorFullName: 'Minjung Noh',
      authorFirstName: 'Minjung',
      authorLastName: 'Noh',
      keywords: 'Korean Evangelicalism',
      articleAbstract: 'This article examines the political resonance of contemporary Korean evangelicalism...',
      articleBody: '<p>This is a simulated body of the article containing Transnational Politics...</p>',
      authorOrcid: '',
      authorAffiliation: '',
      authorBio: '',
      volume: '8',
      issue: '1',
      articleId: '101',
      submissionId: '101',
      issueViewId: '',
      pdfGalleyId: '',
      publishedDate: '',
      issuedDate: '',
      publishedDateMonYYYY: '',
      publishYear: '',
      submittedDate: '',
      modifiedDate: '',
      titleMain: 'Transnational Politics and Korean Evangelicalism',
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder findTextFieldByLabel(String labelText) {
    return find.descendant(
      of: find.byWidgetPredicate((widget) =>
          widget is LabeledTextField && widget.label == labelText),
      matching: find.byType(TextField),
    );
  }

  String getTextFieldText(WidgetTester tester, String labelText) {
    final textField = tester.widget<TextField>(findTextFieldByLabel(labelText));
    return textField.controller?.text ?? '';
  }

  testWidgets('Reset form and clear previous metadata when new file is processed', (WidgetTester tester) async {
    final fakeDocxParser = FakeDocxParser();

    // Set a larger physical size to avoid overflow warnings
    tester.view.physicalSize = const Size(1400, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build the GeneratorScreen widget
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', 'US'),
        ],
        home: GeneratorScreen(docxParser: fakeDocxParser),
      ),
    );

    // Setup required settings fields before testing
    final generatorState = tester.state(find.byType(GeneratorScreen)) as dynamic;
    generatorState.controller.journalNameCtrl.text = 'Test Journal';
    generatorState.controller.journalBaseUrlCtrl.text = 'https://test-journal.com';
    generatorState.controller.journalPathCtrl.text = 'test';
    await tester.pumpAndSettle();

    // 1. Manually populate some fields as if from a previous run
    await tester.enterText(findTextFieldByLabel('Article Title'), 'Previous Article Title');
    await tester.enterText(findTextFieldByLabel('Volume'), '99');
    await tester.enterText(findTextFieldByLabel('Issue'), '99');
    await tester.enterText(findTextFieldByLabel('Article ID'), '999');
    await tester.enterText(findTextFieldByLabel('PDF Galley ID'), '888');
    await tester.enterText(findTextFieldByLabel('Full Name'), 'Previous Author');

    // Verify they are populated
    expect(getTextFieldText(tester, 'Article Title'), 'Previous Article Title');
    expect(getTextFieldText(tester, 'Volume'), '99');
    expect(getTextFieldText(tester, 'Issue'), '99');
    expect(getTextFieldText(tester, 'Article ID'), '999');
    expect(getTextFieldText(tester, 'PDF Galley ID'), '888');
    expect(getTextFieldText(tester, 'Full Name'), 'Previous Author');

    // 2. Locate DropZone and drop a new file
    final dropZoneFinder = find.byType(DropZone);
    expect(dropZoneFinder, findsOneWidget);
    final dropZone = tester.widget<DropZone>(dropZoneFinder);

    final docxFile = File('dummy.docx');

    // Call onFilePicked
    await tester.runAsync(() async {
      dropZone.onFilePicked(docxFile);
      
      // Let's verify that fields are cleared immediately at the start of _processFile
      expect(getTextFieldText(tester, 'Article Title'), '');
      expect(getTextFieldText(tester, 'Volume'), '');
      expect(getTextFieldText(tester, 'Issue'), '');
      expect(getTextFieldText(tester, 'Article ID'), '');
      expect(getTextFieldText(tester, 'PDF Galley ID'), '');
      expect(getTextFieldText(tester, 'Full Name'), '');

      // Wait for the asynchronous parsing task to finish
      await Future<void>.delayed(const Duration(seconds: 4));
    });

    await tester.pumpAndSettle();

    // 3. Verify that the new metadata is populated correctly
    expect(getTextFieldText(tester, 'Article Title'), contains('Transnational Politics'));
    expect(getTextFieldText(tester, 'Full Name'), 'Minjung Noh');
    expect(getTextFieldText(tester, 'Volume'), '8');
    expect(getTextFieldText(tester, 'Issue'), '1');

    // 4. Crucially: Verify that fields NOT populated by the docx are blank (e.g. pdfGalleyId)
    // and do not retain the previous values ('888' or '999')
    expect(getTextFieldText(tester, 'PDF Galley ID'), '');

    // Allow pending timers (like ORCID lookup debounce) to complete before disposing
    await tester.pump(const Duration(seconds: 2));
  });
}
