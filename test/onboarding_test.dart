import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html_galley_generator/features/generator/screens/generator_screen.dart';
import 'package:html_galley_generator/features/generator/widgets/onboarding_dialog.dart';

void main() {
  Widget buildTestableWidget() {
    return const MaterialApp(
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
    );
  }

  testWidgets('OnboardingDialog is shown automatically when first opened',
      (WidgetTester tester) async {
    // Set SharedPreferences value to false (not shown yet)
    SharedPreferences.setMockInitialValues({'hasShownOnboarding': false});

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verify OnboardingDialog is in the widget tree
    expect(find.byType(OnboardingDialog), findsOneWidget);
    expect(find.text('Welcome & Quick Start Guide'), findsOneWidget);

    // Verify step texts and tips are present
    expect(find.text('Configure Journal Settings'), findsOneWidget);
    expect(find.text('Upload Your DOCX File'), findsOneWidget);
    expect(find.text('Verify & Auto-Fill Metadata'), findsOneWidget);
    expect(find.text('Generate & Preview'), findsOneWidget);
    expect(find.text('Pro Tips for Perfect Formatting'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Clean Input = Clean Output:'),
      ),
      findsOneWidget,
    );

    // Tap "Get Started" to dismiss
    final getStartedButton = find.text('Get Started');
    expect(getStartedButton, findsOneWidget);
    await tester.tap(getStartedButton);
    await tester.pumpAndSettle();

    // Verify dialog is gone
    expect(find.byType(OnboardingDialog), findsNothing);
  });

  testWidgets('OnboardingDialog is NOT shown automatically if already shown',
      (WidgetTester tester) async {
    // Set SharedPreferences value to true
    SharedPreferences.setMockInitialValues({'hasShownOnboarding': true});

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verify OnboardingDialog is NOT in the widget tree
    expect(find.byType(OnboardingDialog), findsNothing);
  });

  testWidgets('AppBar help button opens OnboardingDialog manually',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'hasShownOnboarding': true});

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Find and tap the help button in AppBar
    final helpButton = find.byIcon(Icons.help_outline_rounded);
    expect(helpButton, findsOneWidget);
    await tester.tap(helpButton);
    await tester.pumpAndSettle();

    // Verify OnboardingDialog is shown
    expect(find.byType(OnboardingDialog), findsOneWidget);
  });

  testWidgets('Tapping "How to find settings data" opens settings guide dialog',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'hasShownOnboarding': false});

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verify link is present
    final linkFinder = find.text('How to find settings data');
    expect(linkFinder, findsOneWidget);

    // Tap the link to open the guide
    await tester.tap(linkFinder);
    await tester.pumpAndSettle();

    // Verify the guide dialog is displayed with title and image
    expect(find.text('How to Find Settings Data'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Tap close button on the guide dialog
    final closeButtonFinder = find.descendant(
      of: find.byType(Dialog),
      matching: find.byIcon(Icons.close),
    );
    expect(closeButtonFinder, findsNWidgets(2));
    await tester.tap(closeButtonFinder.last);
    await tester.pumpAndSettle();

    // Verify the guide dialog is dismissed, but onboarding dialog remains
    expect(find.text('How to Find Settings Data'), findsNothing);
    expect(find.byType(OnboardingDialog), findsOneWidget);
  });
}
