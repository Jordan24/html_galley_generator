import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html_galley_generator/features/generator/screens/generator_screen.dart';
import 'package:html_galley_generator/features/generator/screens/editor_screen.dart';
import 'package:html_galley_generator/features/generator/widgets/drop_zone.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Generate HTML Galley from parsed DOCX', (WidgetTester tester) async {
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

    // Find DropZone
    final dropZoneFinder = find.byType(DropZone);
    expect(dropZoneFinder, findsOneWidget);
    final dropZone = tester.widget<DropZone>(dropZoneFinder);
    
    print('Invoking onFilePicked on DropZone inside runAsync...');
    final file = File('/Users/jordan/Code/Projects/html_galleys/html_galley_generator/assets/[STYLED] NOH Minjung_Transnational Asia_V8I1_Transnational Politics and Korean Evangelicalism.docx');
    
    await tester.runAsync(() async {
      dropZone.onFilePicked(file);
      print('Waiting for real I/O and parsing to complete...');
      await Future.delayed(const Duration(seconds: 4));
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
      await Future.delayed(const Duration(seconds: 4));
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
