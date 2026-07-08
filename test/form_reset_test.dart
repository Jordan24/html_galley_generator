import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html_galley_generator/features/generator/screens/generator_screen.dart';
import 'package:html_galley_generator/features/generator/widgets/drop_zone.dart';
import 'package:html_galley_generator/features/generator/widgets/labeled_text_field.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder findTextFieldByLabel(String labelText) {
    return find.descendant(
      of: find.ancestor(
        of: find.text(labelText),
        matching: find.byType(LabeledTextField),
      ),
      matching: find.byType(TextField),
    );
  }

  String getTextFieldText(WidgetTester tester, String labelText) {
    final textField = tester.widget<TextField>(findTextFieldByLabel(labelText));
    return textField.controller?.text ?? '';
  }

  testWidgets('Reset form and clear previous metadata when new file is processed', (WidgetTester tester) async {
    // Set a larger physical size to avoid overflow warnings
    tester.view.physicalSize = const Size(1400, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build the GeneratorScreen widget
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en', 'US'),
        ],
        home: GeneratorScreen(),
      ),
    );

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

    final docxFile = File('assets/[STYLED] CHEUNG Kin_Transnational Asia_V8I1_A Chinese American Node of Healing.docx');
    expect(docxFile.existsSync(), isTrue);

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
      await Future.delayed(const Duration(seconds: 4));
    });

    await tester.pumpAndSettle();

    // 3. Verify that the new metadata is populated correctly
    expect(getTextFieldText(tester, 'Article Title'), contains('A Chinese American Node of Healing'));
    expect(getTextFieldText(tester, 'Full Name'), 'Kin Cheung');
    expect(getTextFieldText(tester, 'Volume'), '8');
    expect(getTextFieldText(tester, 'Issue'), '1');

    // 4. Crucially: Verify that fields NOT populated by the docx are blank (e.g. pdfGalleyId)
    // and do not retain the previous values ('888' or '999')
    expect(getTextFieldText(tester, 'PDF Galley ID'), '');

    // Allow pending timers (like ORCID lookup debounce) to complete before disposing
    await tester.pump(const Duration(seconds: 2));
  });
}
