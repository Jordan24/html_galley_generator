import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html_galley_generator/features/generator/screens/generator_screen.dart';
import 'package:html_galley_generator/features/generator/screens/editor_screen.dart';
import 'package:html_galley_generator/features/generator/widgets/drop_zone.dart';
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
      articleBody: '<p>This is a simulated body of the article containing Transnational Politics, affective infrastructure, and contemporary history. It is intentionally lengthened to ensure the Quill editor parsing test passes successfully.</p>',
      authorOrcid: '',
      authorAffiliation: '',
      authorBio: '',
      volume: '8',
      issue: '1',
      articleId: '101',
      submissionId: '101',
      publicationId: '201',
      issueViewId: '301',
      pdfGalleyId: '401',
      publishedDate: '2026-07-14',
      issuedDate: '2026-07-14',
      publishedDateMonYYYY: 'Jul 2026',
      publishYear: '2026',
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

  testWidgets('Generate HTML Galley from parsed DOCX', (WidgetTester tester) async {
    final fakeDocxParser = FakeDocxParser();

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

    // Setup required settings fields before file picking
    final generatorState = tester.state(find.byType(GeneratorScreen)) as dynamic;
    generatorState.controller.journalNameCtrl.text = 'Test Journal';
    generatorState.controller.journalBaseUrlCtrl.text = 'https://test-journal.com';
    generatorState.controller.journalPathCtrl.text = 'test';
    await tester.pump();

    // Find DropZone
    final dropZoneFinder = find.byType(DropZone);
    expect(dropZoneFinder, findsOneWidget);
    final dropZone = tester.widget<DropZone>(dropZoneFinder);
    
    print('Invoking onFilePicked on DropZone inside runAsync...');
    final file = File('dummy.docx');
    
    await tester.runAsync(() async {
      dropZone.onFilePicked(file);
      print('Waiting for real I/O and parsing to complete...');
      await Future<void>.delayed(const Duration(seconds: 4));
    });
    
    print('Pumping state change...');
    await tester.pumpAndSettle();
    
    // Check if form is populated by looking for some text
    final titleFieldFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text.contains('Transnational Politics') == true,
    );
    expect(titleFieldFinder, findsAtLeastNWidgets(1));
    print('Found populated Title fields!');
    
    // Tap the Generate button
    final generateButtonFinder = find.text('Generate HTML Galley');
    expect(generateButtonFinder, findsOneWidget);
    
    print('Tapping Generate HTML Galley button...');
    await tester.tap(generateButtonFinder);
    
    print('Pumping route transition...');
    await tester.pump(); // Starts the navigation transition
    await tester.pump(const Duration(seconds: 1)); // Pushes the transition forward
    
    print('Checking if EditorScreen is in the tree...');
    expect(find.byType(EditorScreen), findsOneWidget);
    print('Found EditorScreen in tree!');
    
    print('Waiting for EditorScreen loading to complete...');
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 4));
    });
    await tester.pumpAndSettle();
    
    // Check if the EditorScreen finished loading and didn't fail
    final editorState = tester.state<State<EditorScreen>>(find.byType(EditorScreen));
    final dynamicEditorState = editorState as dynamic;
    
    print('Editor isLoading: ${dynamicEditorState.isLoading}');
    expect(dynamicEditorState.isLoading, false);
    
    final docLength = dynamicEditorState.controller.document.length;
    print('Quill document length: $docLength');
    expect(docLength, greaterThan(100));
    
    print('Test finished successfully!');
  });
}
